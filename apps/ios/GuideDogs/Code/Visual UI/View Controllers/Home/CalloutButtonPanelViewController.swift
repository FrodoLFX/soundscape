//
//  CalloutButtonPanelViewController.swift
//  same file name, now with a responsive grid + a few quality-of-life features:
//  - 2-per-row big round buttons (fills space)
//  - drag & drop to reorder (persists)
//  - pinch to resize button scale (persists)
//  - long-press menu for High Contrast / Reduce Motion + quick help
//  comments are casual on purpose :)
//
import Foundation
import UIKit
import NVActivityIndicatorView

private enum Prefs {
    static let order = "callout.grid.order.v1"
    static let scale = "callout.grid.scale.v1"
    static let highContrast = "callout.grid.highContrast.v1"
    static let reduceMotion = "callout.grid.reduceMotion.v1"
}

class CalloutButtonPanelViewController: UIViewController, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout, UICollectionViewDragDelegate, UICollectionViewDropDelegate {

    // paddings: big targets, little chrome
    private let hPad: CGFloat = 20
    private let vPad: CGFloat = 20
    private var cellSpacing: CGFloat = 16 {
        didSet { collection?.collectionViewLayout.invalidateLayout() }
    }

    // scale so folks can pinch buttons larger/smaller (still 2-across)
    private var cellScale: CGFloat = 1.0 {
        didSet {
            cellScale = max(0.85, min(cellScale, 1.4))
            UserDefaults.standard.set(cellScale, forKey: Prefs.scale)
            collection?.collectionViewLayout.invalidateLayout()
        }
    }

    private var collection: UICollectionView!
    private var items: [Item] = [] {
        didSet { saveOrder() }
    }

    // style toggles
    private var highContrast = UserDefaults.standard.bool(forKey: Prefs.highContrast) {
        didSet { UserDefaults.standard.set(highContrast, forKey: Prefs.highContrast); collection?.reloadData() }
    }
    private var reduceMotion = UserDefaults.standard.bool(forKey: Prefs.reduceMotion) {
        didSet { UserDefaults.standard.set(reduceMotion, forKey: Prefs.reduceMotion) }
    }

    var logContext: String?

    // same actions, just packaged
    private struct Item: Codable, Hashable {
        let title: String
        let symbol: String
        let accHint: String
        let id: String
        let actionKey: String  // we map to the handler instead of storing closures (so we can persist)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground

        // hide old storyboard blocks so we can own the space
        [headerLabel,
         locateContainer, orientContainer, exploreContainer, markedPointsContainer
        ].forEach { $0?.isHidden = true }
        buttonLabels?.forEach { $0.isHidden = true }

        // defaults
        cellScale = UserDefaults.standard.object(forKey: Prefs.scale) as? CGFloat ?? 1.0

        // build items with stable ids + action keys
        let baseItems: [Item] = [
            Item(title: GDLocalizedString("directions.my_location"),
                 symbol: "location.fill",
                 accHint: GDLocalizedString("ui.action_button.my_location.acc_hint"),
                 id: "btn.mylocation",
                 actionKey: "locate"),
            Item(title: GDLocalizedString("help.orient.page_title"),
                 symbol: "arrow.triangle.2.circlepath",
                 accHint: GDLocalizedString("ui.action_button.around_me.acc_hint"),
                 id: "btn.aroundme",
                 actionKey: "orient"),
            Item(title: GDLocalizedString("help.explore.page_title"),
                 symbol: "arrow.up.circle.fill",
                 accHint: GDLocalizedString("ui.action_button.ahead_of_me.acc_hint"),
                 id: "btn.aheadofme",
                 actionKey: "ahead"),
            Item(title: GDLocalizedString("callouts.nearby_markers"),
                 symbol: "mappin.circle.fill",
                 accHint: GDLocalizedString("ui.action_button.nearby_markers.acc_hint"),
                 id: "btn.nearbymarkers",
                 actionKey: "markers"),
        ]
        items = restoreOrder(fallback: baseItems)

        // flow layout for 2 columns
        let layout = UICollectionViewFlowLayout()
        layout.minimumInteritemSpacing = cellSpacing
        layout.minimumLineSpacing = cellSpacing

        collection = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collection.backgroundColor = .clear
        collection.alwaysBounceVertical = false
        collection.dataSource = me()
        collection.delegate = me()
        collection.dragDelegate = me()
        collection.dropDelegate = me()
        collection.dragInteractionEnabled = true
        collection.translatesAutoresizingMaskIntoConstraints = false
        collection.register(ButtonCell.self, forCellWithReuseIdentifier: "cell")

        // gestures: pinch to resize
        let pinch = UIPinchGestureRecognizer(target: self, action: #selector(handlePinch(_:)))
        collection.addGestureRecognizer(pinch)

        view.addSubview(collection)
        NSLayoutConstraint.activate([
            collection.topAnchor.constraint(equalTo: view.topAnchor, constant: vPad),
            collection.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: hPad),
            collection.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -hPad),
            collection.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -vPad),
        ])

        // keep a11y traversal tight
        view.shouldGroupAccessibilityChildren = true

        // notifications still work
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

    private func performAction(for key: String, endId: String) {
        switch key {
        case "locate":
            let done: (Bool) -> Void = { [weak self] _ in self?.endLoading(for: endId) }
            if let preview = AppContext.shared.eventProcessor.activeBehavior as? PreviewBehavior<IntersectionDecisionPoint> {
                AppContext.process(PreviewMyLocationEvent(current: preview.currentDecisionPoint.value, completionHandler: done))
            } else {
                AppContext.process(ExplorationModeToggled(.locate, sender: self, logContext: logContext, completion: done))
            }
        case "orient":
            AppContext.process(ExplorationModeToggled(.aroundMe, sender: self, logContext: logContext) { [weak self] _ in
                self?.endLoading(for: endId)
            })
        case "ahead":
            AppContext.process(ExplorationModeToggled(.aheadOfMe, sender: self, logContext: logContext) { [weak self] _ in
                self?.endLoading(for: endId)
            })
        case "markers":
            AppContext.process(ExplorationModeToggled(.nearbyMarkers, sender: self, logContext: logContext) { [weak self] _ in
                self?.endLoading(for: endId)
            })
        default:
            // nothing
            endLoading(for: endId)
        }
    }

    // MARK: - Notifications passthrough (names unchanged)

    private func setupNotifications() {
        NotificationCenter.default.addObserver(self, selector: #selector(handleDidToggleLocateNotification(_:)), name: .didToggleLocate, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleDidToggleOrientateNotification(_:)), name: .didToggleOrientate, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleDidToggleLookAheadNotification(_:)), name: .didToggleLookAhead, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleDidToggleMarkedPointsNotification(_:)), name: .didToggleMarkedPoints, object: nil)
    }

    @objc func handleDidToggleLocateNotification(_ n: Notification) { performAction(for: "locate", endId: "btn.mylocation") }
    @objc func handleDidToggleOrientateNotification(_ n: Notification) { performAction(for: "orient", endId: "btn.aroundme") }
    @objc func handleDidToggleLookAheadNotification(_ n: Notification) { performAction(for: "ahead", endId: "btn.aheadofme") }
    @objc func handleDidToggleMarkedPointsNotification(_ n: Notification) { performAction(for: "markers", endId: "btn.nearbymarkers") }

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
        cell.configure(title: item.title,
                       symbol: item.symbol,
                       accHint: item.accHint,
                       id: item.id,
                       highContrast: highContrast,
                       reduceMotion: reduceMotion)

        // tap -> perform mapped action
        cell.onTap = { [weak self, weak cell] in
            cell?.showLoading(true)
            self?.performAction(for: item.actionKey, endId: item.id)
        }

        // add context menu for quick toggles + help
        if cell.menuProvider == nil {
            cell.menuProvider = { [weak self] in
                guard let self = self else { return nil }
                let hc = UIAction(title: self.highContrast ? "Disable High Contrast" : "Enable High Contrast",
                                  image: UIImage(systemName: "circle.lefthalf.fill")) { _ in
                    self.highContrast.toggle()
                }
                let rm = UIAction(title: self.reduceMotion ? "Disable Reduce Motion" : "Enable Reduce Motion",
                                  image: UIImage(systemName: "tortoise")) { _ in
                    self.reduceMotion.toggle()
                }
                let help = UIAction(title: "What does this do?", image: UIImage(systemName: "questionmark.circle")) { _ in
                    let msg = "\(item.title): \(item.accHint)"
                    let alert = UIAlertController(title: item.title, message: msg, preferredStyle: .alert)
                    alert.addAction(UIAlertAction(title: "OK", style: .default))
                    self.present(alert, animated: true)
                }
                return UIMenu(title: "Options", children: [hc, rm, help])
            }
        }

        return cell
    }

    // MARK: - UICollectionViewDelegateFlowLayout (2 per row, round)

    func collectionView(_ collectionView: UICollectionView, layout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        let columns: CGFloat = 2
        let totalSpacing = cellSpacing * (columns - 1)
        let usableW = collectionView.bounds.width - totalSpacing
        let baseSide = floor(usableW / columns)
        let side = floor(baseSide * cellScale)
        return CGSize(width: side, height: side) // height==width -> circles
    }

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumInteritemSpacingForSectionAt section: Int) -> CGFloat {
        return cellSpacing
    }
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumLineSpacingForSectionAt section: Int) -> CGFloat {
        return cellSpacing
    }

    // MARK: - Drag & Drop (reorder + persist)

    func collectionView(_ collectionView: UICollectionView, itemsForBeginning session: UIDragSession, at indexPath: IndexPath) -> [UIDragItem] {
        let item = items[indexPath.item]
        let provider = NSItemProvider(object: item.id as NSString)
        let drag = UIDragItem(itemProvider: provider)
        drag.localObject = item
        return [drag]
    }

    func collectionView(_ collectionView: UICollectionView, canHandle session: UIDropSession) -> Bool { return true }
    func collectionView(_ collectionView: UICollectionView, dropSessionDidUpdate session: UIDropSession, withDestinationIndexPath destinationIndexPath: IndexPath?) -> UICollectionViewDropProposal {
        return UICollectionViewDropProposal(operation: .move, intent: .insertAtDestinationIndexPath)
    }

    func collectionView(_ collectionView: UICollectionView, performDropWith coordinator: UICollectionViewDropCoordinator) {
        guard let item = coordinator.items.first, let sourceIndex = item.sourceIndexPath else { return }
        let dest = coordinator.destinationIndexPath ?? IndexPath(item: items.count - 1, section: 0)
        collectionView.performBatchUpdates({
            let moved = items.remove(at: sourceIndex.item)
            items.insert(moved, at: dest.item)
            collectionView.deleteItems(at: [sourceIndex])
            collectionView.insertItems(at: [dest])
        }, completion: nil)
        coordinator.drop(item.dragItem, toItemAt: dest)
    }

    private func saveOrder() {
        // persist ids
        let ids = items.map { $0.id }
        UserDefaults.standard.set(ids, forKey: Prefs.order)
    }

    private func restoreOrder(fallback: [Item]) -> [Item] {
        guard let ids = UserDefaults.standard.array(forKey: Prefs.order) as? [String], !ids.isEmpty else { return fallback }
        let map = Dictionary(uniqueKeysWithValues: fallback.map { ($0.id, $0) })
        var restored: [Item] = []
        for id in ids {
            if let it = map[id] { restored.append(it) }
        }
        // add any new items we didn't know about previously
        for it in fallback where !ids.contains(it.id) {
            restored.append(it)
        }
        return restored
    }

    // MARK: - Gestures

    @objc private func handlePinch(_ g: UIPinchGestureRecognizer) {
        switch g.state {
        case .changed, .ended:
            // less formal math: bigger pinch -> bigger buttons
            cellScale *= g.scale
            g.scale = 1
        default:
            break
        }
    }

    // convenience because protocol conformances want `self`
    private func me<T>() -> T { return self as! T }

    // MARK: - Old storyboard outlets (kept so IB won’t complain)
    @IBOutlet weak var headerLabel: UILabel?
    @IBOutlet weak var locateContainer: UIView?
    @IBOutlet weak var orientContainer: UIView?
    @IBOutlet weak var exploreContainer: UIView?
    @IBOutlet weak var markedPointsContainer: UIView?
    @IBOutlet var buttonLabels: [UILabel]?

    // MARK: - Inner Cell

    private final class ButtonCell: UICollectionViewCell {
        private let button: AccessibleCircularButton
        var onTap: (() -> Void)?

        // simple provider hook so VC can supply a UIMenu
        var menuProvider: (() -> UIMenu?)? {
            didSet {
                if contextMenu == nil {
                    let i = UIContextMenuInteraction(delegate: self)
                    addInteraction(i)
                    contextMenu = i
                }
            }
        }
        private var contextMenu: UIContextMenuInteraction?

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
            isAccessibilityElement = false
        }

        required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

        func configure(title: String, symbol: String, accHint: String, id: String, highContrast: Bool, reduceMotion: Bool) {
            accessibilityIdentifier = id
            button.accessibilityIdentifier = id
            button.accessibilityLabel = title
            button.accessibilityHint = accHint

            // update text + icon inside existing control (keeps haptics/spinner)
            if let lbl = button.subviews.compactMap({ $0 as? UILabel }).first {
                lbl.text = title
                lbl.adjustsFontForContentSizeCategory = true
                lbl.numberOfLines = 2
                lbl.textAlignment = .center
            }
            if let img = button.subviews.compactMap({ $0 as? UIImageView }).first {
                let config = UIImage.SymbolConfiguration(pointSize: max(20, bounds.width * 0.25), weight: .semibold)
                img.image = UIImage(systemName: symbol, withConfiguration: config)
                img.isAccessibilityElement = false
            }

            // style tweaks
            layer.masksToBounds = false
            contentView.layer.masksToBounds = false
            button.layer.masksToBounds = true

            // high contrast = thicker ring + system label on systemBlue
            if highContrast {
                button.backgroundColor = UIColor.systemBlue
                button.layer.borderWidth = 4
                button.layer.borderColor = UIColor.label.withAlphaComponent(0.9).cgColor
                button.tintColor = .white
                if let lbl = button.subviews.compactMap({ $0 as? UILabel }).first {
                    lbl.textColor = .white
                }
            } else {
                button.backgroundColor = UIColor.secondarySystemBackground
                button.layer.borderWidth = 1
                button.layer.borderColor = UIColor.separator.cgColor
                button.tintColor = .label
                if let lbl = button.subviews.compactMap({ $0 as? UILabel }).first {
                    lbl.textColor = .label
                }
            }

            // reduce motion? keep it chill
            if !reduceMotion {
                // tiny pulse when cells appear
                button.alpha = 0.0
                UIView.animate(withDuration: 0.25, delay: 0.02, options: [.allowUserInteraction], animations: {
                    self.button.alpha = 1.0
                }, completion: nil)
            } else {
                button.alpha = 1.0
            }
        }

        func showLoading(_ on: Bool) {
            on ? button.showLoadingAnimation() : button.hideLoadingAnimation()
        }

        @objc private func tap() { onTap?() }
    }
}

// MARK: - Context Menu Delegate
extension CalloutButtonPanelViewController.ButtonCell: UIContextMenuInteractionDelegate {
    func contextMenuInteraction(_ interaction: UIContextMenuInteraction, configurationForMenuAtLocation location: CGPoint) -> UIContextMenuConfiguration? {
        return UIContextMenuConfiguration(identifier: nil, previewProvider: nil) { [weak self] _ in
            return self?.menuProvider?()
        }
    }
}
