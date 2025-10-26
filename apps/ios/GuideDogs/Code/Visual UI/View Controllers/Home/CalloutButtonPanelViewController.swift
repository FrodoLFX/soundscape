//

import Foundation
import UIKit
import NVActivityIndicatorView

class CalloutButtonPanelViewController: UIViewController, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {

    // chill spacings so the buttons can breathe but still go big
    private let hPad: CGFloat = 20
    private let vPad: CGFloat = 20
    private let cellSpacing: CGFloat = 16

    private var collection: UICollectionView!
    private var items: [Item] = []

    var logContext: String?

    // tiny item model so we don’t lose track of actions
    private struct Item {
        let title: String
        let symbol: String
        let accHint: String
        let id: String
        let tap: () -> Void
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground

        // hide the legacy containers; we’re taking over the whole panel
        [headerLabel,
         locateContainer, orientContainer, exploreContainer, markedPointsContainer
        ].forEach { $0?.isHidden = true }

        // mirror your original four actions, just with a grid backing them
        items = [
            Item(title: GDLocalizedString("directions.my_location"),
                 symbol: "location.fill",
                 accHint: GDLocalizedString("ui.action_button.my_location.acc_hint"),
                 id: "btn.mylocation",
                 tap: { [weak self] in self?.onLocate() }),
            Item(title: GDLocalizedString("help.orient.page_title"),
                 symbol: "arrow.triangle.2.circlepath",
                 accHint: GDLocalizedString("ui.action_button.around_me.acc_hint"),
                 id: "btn.aroundme",
                 tap: { [weak self] in self?.onOrientate() }),
            Item(title: GDLocalizedString("help.explore.page_title"),
                 symbol: "arrow.up.circle.fill",
                 accHint: GDLocalizedString("ui.action_button.ahead_of_me.acc_hint"),
                 id: "btn.aheadofme",
                 tap: { [weak self] in self?.onLookAhead() }),
            Item(title: GDLocalizedString("callouts.nearby_markers"),
                 symbol: "mappin.circle.fill",
                 accHint: GDLocalizedString("ui.action_button.nearby_markers.acc_hint"),
                 id: "btn.nearbymarkers",
                 tap: { [weak self] in self?.onMarkedPoints() })
        ]

        let layout = UICollectionViewFlowLayout()
        layout.minimumInteritemSpacing = cellSpacing
        layout.minimumLineSpacing = cellSpacing

        collection = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collection.backgroundColor = .clear
        collection.alwaysBounceVertical = false
        collection.dataSource = self
        collection.delegate = self
        collection.translatesAutoresizingMaskIntoConstraints = false
        collection.register(ButtonCell.self, forCellWithReuseIdentifier: "cell")

        view.addSubview(collection)
        NSLayoutConstraint.activate([
            collection.topAnchor.constraint(equalTo: view.topAnchor, constant: vPad),
            collection.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: hPad),
            collection.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -hPad),
            collection.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -vPad),
        ])

        view.shouldGroupAccessibilityChildren = true
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        // claim a tall preferred height so the grid can scale up and eat blank space
        let minHeight = view.bounds.width // roughly “two rows of big circles”
        preferredContentSize = CGSize(width: view.bounds.width, height: max(480, minHeight))
        collection.collectionViewLayout.invalidateLayout()
    }

    // MARK: - Actions (unchanged behavior, just routed through grid)

    private func onLocate() {
        let done: (Bool) -> Void = { [weak self] _ in self?.endLoading(for: "btn.mylocation") }
        if let preview = AppContext.shared.eventProcessor.activeBehavior as? PreviewBehavior<IntersectionDecisionPoint> {
            AppContext.process(PreviewMyLocationEvent(current: preview.currentDecisionPoint.value, completionHandler: done))
        } else {
            AppContext.process(ExplorationModeToggled(.locate, sender: self, logContext: logContext, completion: done))
        }
    }

    private func onOrientate() {
        AppContext.process(ExplorationModeToggled(.aroundMe, sender: self, logContext: logContext) { [weak self] _ in
            self?.endLoading(for: "btn.aroundme")
        })
    }

    private func onLookAhead() {
        AppContext.process(ExplorationModeToggled(.aheadOfMe, sender: self, logContext: logContext) { [weak self] _ in
            self?.endLoading(for: "btn.aheadofme")
        })
    }

    private func onMarkedPoints() {
        AppContext.process(ExplorationModeToggled(.nearbyMarkers, sender: self, logContext: logContext) { [weak self] _ in
            self?.endLoading(for: "btn.nearbymarkers")
        })
    }

    // let remote-control / notifications keep working
    @objc func handleDidToggleLocateNotification(_ n: Notification) { onLocate() }
    @objc func handleDidToggleOrientateNotification(_ n: Notification) { onOrientate() }
    @objc func handleDidToggleLookAheadNotification(_ n: Notification) { onLookAhead() }
    @objc func handleDidToggleMarkedPointsNotification(_ n: Notification) { onMarkedPoints() }

    // MARK: - UICollectionViewDataSource

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int { items.count }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "cell", for: indexPath) as! ButtonCell
        let item = items[indexPath.item]
        cell.configure(title: item.title, symbol: item.symbol, accHint: item.accHint, id: item.id)
        cell.onTap = { [weak self, weak cell] in
            cell?.showLoading(true)
            item.tap()
        }
        return cell
    }

    // MARK: - UICollectionViewDelegateFlowLayout (2 per row, round)

    func collectionView(_ collectionView: UICollectionView, layout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        let columns: CGFloat = 2
        let totalSpacing = cellSpacing * (columns - 1)
        let usableW = collectionView.bounds.width - totalSpacing
        let side = floor(usableW / columns)
        // height == width -> perfect circle
        return CGSize(width: side, height: side)
    }

    // flip spinner off by id when action completes
    private func endLoading(for id: String) {
        for case let c as ButtonCell in collection.visibleCells where c.accessibilityIdentifier == id {
            c.showLoading(false)
        }
    }

    // MARK: - Private Cell (stays in this file, no public API changes)

    private final class ButtonCell: UICollectionViewCell {
        private let button: AccessibleCircularButton
        var onTap: (() -> Void)?

        override init(frame: CGRect) {
            // size here is just initial; autolayout will make it square to the cell
            button = AccessibleCircularButton(size: 120, imageName: "circle.fill", title: "", accessibilityHint: "")
            super.init(frame: frame)
            contentView.addSubview(button)
            button.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                button.widthAnchor.constraint(equalTo: contentView.widthAnchor),
                button.heightAnchor.constraint(equalTo: contentView.widthAnchor), // keep round by tying height to width
                button.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
                button.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            ])
            button.addTarget(self, action: #selector(tap), for: .touchUpInside)
        }

        required init?(coder: NSCoder) { fatalError("nope") }

        func configure(title: String, symbol: String, accHint: String, id: String) {
            accessibilityIdentifier = id
            // update a11y text
            button.accessibilityIdentifier = id
            button.accessibilityLabel = title
            button.accessibilityHint = accHint

            // bump the title + symbol inside the existing control (keeps haptics/spinner)
            if let lbl = button.subviews.compactMap({ $0 as? UILabel }).first {
                lbl.text = title
            }
            if let img = button.subviews.compactMap({ $0 as? UIImageView }).first {
                let config = UIImage.SymbolConfiguration(pointSize: max(20, bounds.width * 0.25), weight: .semibold)
                img.image = UIImage(systemName: symbol, withConfiguration: config)
            }
        }

        func showLoading(_ on: Bool) {
            on ? button.showLoadingAnimation() : button.hideLoadingAnimation()
        }

        @objc private func tap() { onTap?() }
    }

    // MARK: - Outlets from the old layout (still here so IB/storyboard won’t freak out)

    @IBOutlet weak var headerLabel: UILabel?
    @IBOutlet weak var locateContainer: UIView?
    @IBOutlet weak var orientContainer: UIView?
    @IBOutlet weak var exploreContainer: UIView?
    @IBOutlet weak var markedPointsContainer: UIView?
}
