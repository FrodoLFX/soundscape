//
//  CalloutButtonPanelViewController.swift
//  same file name, now a responsive grid of big round buttons
//

import Foundation
import UIKit
import NVActivityIndicatorView

class CalloutButtonPanelViewController: UIViewController, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {

    // paddings: big targets, little chrome
    private let hPad: CGFloat = 20
    private let vPad: CGFloat = 20
    private let cellSpacing: CGFloat = 16

    private var collection: UICollectionView!
    private var items: [Item] = []

    var logContext: String?

    // same actions, just packaged
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

        // hide old storyboard blocks so we can own the space
        [headerLabel,
         locateContainer, orientContainer, exploreContainer, markedPointsContainer
        ].forEach { $0?.isHidden = true }
        buttonLabels?.forEach { $0.isHidden = true }

        // build grid items with same semantics as before
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
                 tap: { [weak self] in self?.onMarkedPoints() }),
        ]

        // simple 2-column flow layout; height==width => perfect circles
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

        // keep a11y traversal tight
        view.shouldGroupAccessibilityChildren = true

        // keep remote-control / notifications working
        setupNotifications()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        // ask container for a tall slot so the grid can eat blank space
        let minHeight = view.bounds.width // enough for two big rows
        preferredContentSize = CGSize(width: view.bounds.width, height: max(480, minHeight))
        collection.collectionViewLayout.invalidateLayout()
    }

    // MARK: - Actions (same behavior)

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

    // MARK: - Notifications passthrough (names unchanged)

    private func setupNotifications() {
        NotificationCenter.default.addObserver(self, selector: #selector(handleDidToggleLocateNotification(_:)), name: .didToggleLocate, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleDidToggleOrientateNotification(_:)), name: .didToggleOrientate, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleDidToggleLookAheadNotification(_:)), name: .didToggleLookAhead, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleDidToggleMarkedPointsNotification(_:)), name: .didToggleMarkedPoints, object: nil)
    }

    @objc func handleDidToggleLocateNotification(_ n: Notification) { onLocate() }
    @objc func handleDidToggleOrientateNotification(_ n: Notification) { onOrientate() }
    @objc func handleDidToggleLookAheadNotification(_ n: Notification) { onLookAhead() }
    @objc func handleDidToggleMarkedPointsNotification(_ n: Notification) { onMarkedPoints() }

    // flip spinner off by id when action completes
    private func endLoading(for id: String) {
        for case let c as ButtonCell in collection.visibleCells where c.accessibilityIdentifier == id {
            c.showLoading(false)
        }
    }

    // MARK: - UICollectionViewDataSource

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int { items.count }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "cell", for: indexPath) as! ButtonCell
        let item = items[indexPath.item]
        cell.configure(title: item.title, symbol: item.symbol, accHint: item.accHint, id: item.id)
        cell.onTap = { [weak cell] in
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
        return CGSize(width: side, height: side) // height==width -> circles
    }

    // MARK: - Private Cell (stays local, no new public API)

    private final class ButtonCell: UICollectionViewCell {
        private let button: AccessibleCircularButton
        var onTap: (() -> Void)?

        override init(frame: CGRect) {
            button = AccessibleCircularButton(size: 120, imageName: "circle.fill", title: "", accessibilityHint: "")
            super.init(frame: frame)
            contentView.addSubview(button)
            button.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                button.widthAnchor.constraint(equalTo: contentView.widthAnchor),
                button.heightAnchor.constraint(equalTo: contentView.widthAnchor), // tie height to width to keep it round
                button.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
                button.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            ])
            button.addTarget(self, action: #selector(tap), for: .touchUpInside)
        }

        required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

        func configure(title: String, symbol: String, accHint: String, id: String) {
            accessibilityIdentifier = id
            button.accessibilityIdentifier = id
            button.accessibilityLabel = title
            button.accessibilityHint = accHint

            // poke existing subviews (keeps haptics/spinner behavior)
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

    // MARK: - Old storyboard outlets (kept so IB won’t complain)

    @IBOutlet weak var headerLabel: UILabel?
    @IBOutlet weak var locateContainer: UIView?
    @IBOutlet weak var orientContainer: UIView?
    @IBOutlet weak var exploreContainer: UIView?
    @IBOutlet weak var markedPointsContainer: UIView?
    @IBOutlet var buttonLabels: [UILabel]?
}
