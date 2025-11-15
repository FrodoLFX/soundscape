# Licensed under the MIT License.
"""
Defines methods used by ingest.py to populate the non_osm_data table.

If invoked directly, the script will rebuild the non_osm_data table without
reimporting the whole planet. This still needs to run inside an ingest
container, e.g.

  $ docker-compose exec ingest python3 /ingest/ingest_non_osm.py
"""

import os
import csv
import asyncio
import logging

import aiopg

from kubescape import SoundscapeKube

# When importing supplemental (non‑OSM) points of interest, some of those
# features may correspond to existing OSM features at nearly the same
# location (e.g. a non‑OSM bus stop imported from a NaviLens feed that
# overlaps an OSM bus stop).  In such cases we want to avoid creating
# redundant points in the ``non_osm_data`` table.  Instead, we attach any
# additional metadata provided by the supplemental feed to the existing
# OSM feature.  The distance within which two points are considered the
# same location can be tuned via the ``NON_OSM_DEDUP_RADIUS_M`` environment
# variable.  The default is 5 metres.

# Read deduplication radius (in metres) from the environment.  Falling back
# to 5 metres if not set or invalid.
try:
    _radius_env = float(os.environ.get("NON_OSM_DEDUP_RADIUS_M", 5.0))
    DEDUP_RADIUS_M = _radius_env if _radius_env > 0 else 5.0
except (TypeError, ValueError):
    DEDUP_RADIUS_M = 5.0

logging.basicConfig(level=logging.INFO,
                    format='%(asctime)s:%(levelname)s:%(message)s')
logger = logging.getLogger(__name__)


async def provision_non_osm_data_async(osm_dsn: str) -> None:
    """
    Ensure the ``non_osm_data`` table exists and is empty.

    Parameters
    ----------
    osm_dsn: str
        Data source name for connecting to the OSM database.
    """
    async with aiopg.connect(dsn=osm_dsn) as conn:
        async with conn.cursor() as cursor:
            await cursor.execute(
                """CREATE TABLE IF NOT EXISTS non_osm_data (
                    id          BIGSERIAL PRIMARY KEY,
                    osm_id      BIGINT,
                    feature_type TEXT,
                    feature_value TEXT,
                    properties  HSTORE,
                    geom        GEOMETRY(Point, 4326)
                )"""
            )
            # Remove any existing data.  We always rebuild this table from
            # scratch rather than attempting an incremental update.
            await cursor.execute("TRUNCATE non_osm_data")


async def import_non_osm_data_async(csv_dir: str, osm_dsn: str, logger: logging.Logger) -> None:
    """
    Import all CSV files from ``csv_dir`` into the ``non_osm_data`` table, while
    deduplicating any records that overlap existing OSM features within
    ``DEDUP_RADIUS_M`` metres.

    If a supplemental record is found to be within ``DEDUP_RADIUS_M`` of a
    matching OSM place (same ``feature_type`` and ``feature_value``), the
    existing OSM feature's ``properties`` field will be augmented with any
    additional metadata found in the supplemental record.  No row will be
    inserted into ``non_osm_data`` for such duplicates.

    Parameters
    ----------
    csv_dir: str
        Directory containing CSV files with supplemental data.  Each CSV must
        provide ``feature_type``, ``feature_value``, ``longitude`` and
        ``latitude`` columns along with any additional metadata.
    osm_dsn: str
        Data source name for connecting to the OSM database.
    logger: logging.Logger
        Logger used to output status messages.
    """
    # Assign large positive OSM IDs for non‑OSM points to avoid conflicts
    # with real OSM IDs.  We start near 10^17 and increment for each row.
    osm_id_counter = 10 ** 17

    async with aiopg.connect(dsn=osm_dsn) as conn:
        async with conn.cursor() as cursor:
            # Ensure the non_osm_data table is empty before reloading
            await cursor.execute("TRUNCATE non_osm_data")

            for csv_path in os.listdir(csv_dir):
                full_path = os.path.join(csv_dir, csv_path)
                if not os.path.isfile(full_path) or not csv_path.lower().endswith('.csv'):
                    continue
                rowcount = 0
                duplicate_count = 0
                with open(full_path, encoding="utf8") as f:
                    reader = csv.DictReader(f)
                    for row in reader:
                        rowcount += 1
                        osm_id_counter += 1

                        # Extract required fields and convert coordinates
                        feat_type = row.pop("feature_type")
                        feat_value = row.pop('feature_value')
                        try:
                            long = float(row.pop("longitude"))
                            lat = float(row.pop("latitude"))
                        except (KeyError, TypeError, ValueError) as exc:
                            logger.warning(
                                "Skipping row %s in %s due to invalid coordinates: %s",
                                rowcount,
                                csv_path,
                                exc,
                            )
                            continue
                        # Remaining fields become additional properties
                        props = row  # type: ignore[assignment]

                        # Query for matching OSM features within the dedup radius.
                        # We restrict the search to features with matching type and value
                        # to avoid merging dissimilar POIs.  We use geography casts
                        # so that the distance is measured in metres regardless of
                        # longitude/latitude.
                        await cursor.execute(
                            """
                            SELECT osm_id
                              FROM osm_places
                             WHERE feature_type = %s
                               AND feature_value = %s
                               AND ST_DWithin(
                                   geometry::geography,
                                   ST_SetSRID(ST_MakePoint(%s, %s), 4326)::geography,
                                   %s
                               )
                            LIMIT 1
                            """,
                            (feat_type, feat_value, long, lat, DEDUP_RADIUS_M),
                        )
                        existing = await cursor.fetchone()
                        if existing:
                            # A matching OSM feature exists nearby.  Attach any
                            # supplemental properties to the OSM feature using
                            # hstore concatenation.  psycopg2/aiopg will
                            # automatically convert the Python dict to hstore.
                            existing_osm_id = existing[0]
                            if props:
                                await cursor.execute(
                                    """
                                    UPDATE osm_places
                                       SET properties = properties || %s
                                     WHERE osm_id = %s
                                    """,
                                    (props, existing_osm_id),
                                )
                            duplicate_count += 1
                            continue

                        # No matching OSM feature; insert into non_osm_data
                        await cursor.execute(
                            """
                            INSERT INTO non_osm_data
                              (osm_id, feature_type, feature_value, properties, geom)
                            VALUES
                              (%s, %s, %s, %s, ST_SetSRID(ST_MakePoint(%s, %s), 4326))
                            """,
                            (osm_id_counter, feat_type, feat_value, props, long, lat),
                        )

                logger.info(
                    "Loaded %d rows from %s (%d deduplicated)",
                    rowcount,
                    csv_path,
                    duplicate_count,
                )


def import_non_osm_data(csv_dir: str, osm_dsn: str, logger: logging.Logger) -> None:
    """Synchronous wrapper around :func:`import_non_osm_data_async`."""
    loop = asyncio.get_event_loop()
    loop.run_until_complete(import_non_osm_data_async(csv_dir, osm_dsn, logger))


if __name__ == "__main__":
    # When executed directly inside the ingest container, import all CSV files
    # from ``/non_osm_data`` into the configured OSM database for this
    # namespace.  The namespace is passed via an environment variable and
    # resolved into a database DSN by SoundscapeKube.
    namespace = os.environ['NAMESPACE']
    kube = SoundscapeKube(None, namespace)
    import_non_osm_data(
        csv_dir="/non_osm_data",
        osm_dsn=kube.databases["osm"]["dsn2"],
        logger=logger,
    )