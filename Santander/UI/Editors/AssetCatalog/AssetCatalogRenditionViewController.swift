//
//  AssetCatalogRenditionViewController.swift
//  Santander
//
//  Created by Serena on 01/10/2022
//


import UIKit
import AssetCatalogWrapper

class AssetCatalogRenditionViewController: UIViewController {
    typealias DataSource = UICollectionViewDiffableDataSource<Section, ItemType>
    
    typealias DetailCellRegistration = UICollectionView.CellRegistration<UICollectionViewListCell, DetailItem>
    typealias ActionCellRegistration = UICollectionView.CellRegistration<UICollectionViewListCell, ItemAction>
    typealias GridPreviewCellRegistration = UICollectionView.CellRegistration<AssetCatalogGridPreviewCell, Rendition>
    
    var rendition: Rendition
    var collectionView: UICollectionView!
    var dataSource: DataSource!
    var sender: AssetCatalogViewController?
    
    init(rendition: Rendition, sender: AssetCatalogViewController?) {
        self.rendition = rendition
        self.sender = sender
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) hasn't been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        title = "Info"
        configureCollectionView()
        configureDataSource()
        addItems()
    }
    
    func configureCollectionView() {
        self.collectionView = UICollectionView(frame: .zero, collectionViewLayout: makeLayout())
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        collectionView.delegate = self
        collectionView.dragDelegate = self
        view.addSubview(collectionView)
        
        collectionView.constraintCompletely(to: view)
    }
    
    func editItem(sender: AssetCatalogViewController) {
        guard let saveIndx = sender.dataSource.indexPath(for: rendition) else { return }
        sender.editItem(rendition, presentingFrom: self) { [self] error in
            if let error = error {
                errorAlert(error, title: "Failed to edit item")
                return
            }
            
            dismiss(animated: true) {
                guard let newRend = sender.dataSource.itemIdentifier(for: saveIndx) else { return }
                let newVC = UINavigationController(rootViewController: AssetCatalogRenditionViewController(rendition: newRend, sender: sender))
                sender.present(newVC, animated: true)
            }
        }
    }
    
    func makeDetailCellBackgroundConfiguration() -> UIBackgroundConfiguration {
        var background = UIBackgroundConfiguration.listAccompaniedSidebarCell()
        background.cornerRadius = 8
        background.backgroundColor = .tertiarySystemBackground
        return background
    }
    
    func configureDataSource() {
        let listCellSecondaryTextFont: UIFont = .preferredFont(forTextStyle: .footnote)
        let detailCellBackgroundConf = makeDetailCellBackgroundConfiguration()
        
        let detailCellRegistration = DetailCellRegistration { cell, indexPath, details in
            var content = UIListContentConfiguration.cell()
            content.prefersSideBySideTextAndSecondaryText = true
            content.text = details.primaryText
            content.secondaryText = details.secondaryText
            content.secondaryTextProperties.font = listCellSecondaryTextFont
            cell.contentConfiguration = content
            cell.backgroundConfiguration = detailCellBackgroundConf
        }
        
        let previewCellRegistration = GridPreviewCellRegistration { cell, indexPath, itemIdentifier in
            cell.rendition = self.rendition
            cell.configure()
        }
        
        let actionCellRegistration = ActionCellRegistration { cell, indexPath, itemIdentifier in
            var conf = cell.defaultContentConfiguration()
            conf.text = itemIdentifier.displayText
            conf.image = itemIdentifier.displayImage
            conf.imageToTextPadding = 10
            cell.contentConfiguration = conf
            cell.backgroundConfiguration = detailCellBackgroundConf
        }
        
        self.dataSource = DataSource(collectionView: collectionView) { collectionView, indexPath, itemIdentifier in
            switch itemIdentifier {
            case .preview:
                return collectionView.dequeueConfiguredReusableCell(using: previewCellRegistration, for: indexPath, item: self.rendition)
            case .action(let action):
                return collectionView.dequeueConfiguredReusableCell(using: actionCellRegistration, for: indexPath, item: action)
            case .details(let detailItem):
                return collectionView.dequeueConfiguredReusableCell(using: detailCellRegistration, for: indexPath, item: detailItem)
            }
        }
    }
    
    func addItems() {
        var snapshot = NSDiffableDataSourceSnapshot<Section, ItemType>()
        snapshot.appendSections([.itemPreview])
        
        var actions: [ItemAction] = []
        // add actions if possible
        if let image = rendition.image {
            let uiImage = UIImage(cgImage: image)
            
            let saveImageAction = ItemAction(displayText: "Save", displayImage: UIImage(systemName: "square.and.arrow.down")) {
                self.saveImage(uiImage)
            }
            
            let viewImageAction = ItemAction(displayText: "View", displayImage: UIImage(systemName: "magnifyingglass")) {
                let viewer = ImageViewerController(fileURL: nil, image: uiImage, title: self.rendition.name)
                self.present(UINavigationController(rootViewController: viewer), animated: true)
            }
            
            actions += [saveImageAction, viewImageAction]
        }
        
        if rendition.type.isEditable, let sender = sender {
            let editAction = ItemAction(displayText: "Edit", displayImage: UIImage(systemName: "gear")) {
                self.editItem(sender: sender)
            }
            
            actions.append(editAction)
        }
        
        if !actions.isEmpty {
            snapshot.appendSections([.itemActions])
            snapshot.appendItems(actions.map { return ItemType.action($0) }, toSection: .itemActions)
        }
        
        let size = rendition.cuiRend.unslicedSize()
        
        var itemDetails: [DetailItem] = [
        ]
        
        // if rendition name is different than lookup name,
        // then display just "Name"
        // otherwise, if they're different, display them as different cells
        if rendition.namedLookup.name == rendition.namedLookup.renditionName {
            itemDetails.insert(DetailItem(primaryText: "Name", secondaryText: rendition.namedLookup.name), at: 0)
        } else {
            let bothNames = [
                DetailItem(primaryText: "Lookup Name", secondaryText: rendition.namedLookup.name),
                DetailItem(primaryText: "Rendition Name", secondaryText: rendition.namedLookup.renditionName)
            ]
            
            itemDetails.insert(contentsOf: bothNames, at: 0)
        }
        
        // if the height or width aren't 0 (they are 0 in the cases of colors)
        // display them
        if !size.height.isZero {
            itemDetails.append(DetailItem(primaryText: "Height", secondaryText: size.height.description))
        }
        
        if !size.width.isZero {
            itemDetails.append(DetailItem(primaryText: "Width", secondaryText: size.width.description))
        }
        
        itemDetails.append(DetailItem(primaryText: "Scale", secondaryText: rendition.cuiRend.scale().description))
        
        let key = rendition.namedLookup.key
        let rendInfo: [DetailItem] = [
            DetailItem(primaryText: "Idiom", secondaryText: Rendition.Idiom(key)),
            DetailItem(primaryText: "Appearance", secondaryText: Rendition.Appearance(key)),
            DetailItem(primaryText: "Display Gamut", secondaryText: Rendition.DisplayGamut(key)),
            DetailItem(primaryText: "Type", secondaryText: rendition.type),
        ]
        
        snapshot.appendItems([.preview], toSection: .itemPreview)
        snapshot.appendSections([.itemInfo])
        snapshot.appendItems(ItemType.fromDetails(itemDetails), toSection: .itemInfo)
        
        if rendition.type == .multiSizeImageSet,
           let nsObjectSizes = rendition.cuiRend.value(forKey: "sizeIndexes") as? [NSObject] {
            let sizes = nsObjectSizes.compactMap { $0.value(forKey: "size") as? CGSize }
            let items = sizes.enumerated().map { (indx, size) in
                DetailItem(primaryText: "Size \(indx)", secondaryText: "Width: \(size.width), Height: \(size.height)")
            }
            
            snapshot.appendSections([.specificTypeInfo])
            snapshot.appendItems(ItemType.fromDetails(items), toSection: .specificTypeInfo)
        }
        
        switch rendition.representation {
        case .color(let cgColor):
            let uiColor = UIColor(cgColor: cgColor)
            // to easily get blue, red, green, alpha without
            // working with pointers
            let codableColor = CodableColor(uiColor)
            
            let colorSpaceName = (cgColor.colorSpace?.name as? String ?? "N/A")
                .replacingOccurrences(of: "kCGColorSpace", with: "") // remove mentions of "kCGColorSpace" so its only the name
            let colorDetails = [
                DetailItem(primaryText: "ColorSpace", secondaryText: colorSpaceName),
                DetailItem(primaryText: "Red", secondaryText: String(format: "%.3f", codableColor.red)),
                DetailItem(primaryText: "Blue", secondaryText: String(format: "%.3f", codableColor.blue)),
                DetailItem(primaryText: "Green", secondaryText: String(format: "%.3f", codableColor.green)),
            ]
            
            snapshot.insertSections([.specificTypeInfo], afterSection: .itemInfo)
            snapshot.appendItems(ItemType.fromDetails(colorDetails), toSection: .specificTypeInfo)
        default:
            break
        }
        
        snapshot.appendSections([.renditionInformation])
        snapshot.appendItems(ItemType.fromDetails(rendInfo), toSection: .renditionInformation)
        dataSource.apply(snapshot)
    }
    
    func makeLayout() -> UICollectionViewLayout {
        // lazy var, so that it's not nil by the time it's initialized, because makeLayout() is called before createDataSource
        // it won't be nil when it's used in the layout closure.
        lazy var snapshot = dataSource.snapshot()
        let layout = UICollectionViewCompositionalLayout { sectionIndex, enviroment in
            let section = snapshot.sectionIdentifiers[sectionIndex]
            switch section {
            case .itemPreview:
                let itemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0),
                                                     heightDimension: .estimated(180))
                let item = NSCollectionLayoutItem(layoutSize: itemSize)
                let groupSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0),
                                                       heightDimension: .estimated(180))
                let group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, subitem: item, count: 1)
                group.interItemSpacing = .fixed(20)
                
                return NSCollectionLayoutSection(group: group)
            case .itemActions:
                let itemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0),
                                                     heightDimension: .fractionalHeight(1.0))
                let item = NSCollectionLayoutItem(layoutSize: itemSize)

                let groupSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0),
                                                      heightDimension: .absolute(44))
                let group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, subitem: item, count: snapshot.numberOfItems(inSection: section))
                
                let spacing = CGFloat(10)
                group.interItemSpacing = .fixed(spacing)
                
                let section = NSCollectionLayoutSection(group: group)
                section.interGroupSpacing = spacing
                section.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16)
                return section
            default:
                let list = NSCollectionLayoutSection.list(
                    using: .init(appearance: .sidebar),
                    layoutEnvironment: enviroment
                )
                list.interGroupSpacing = 5
                
                return list
            }
        }
        let config = UICollectionViewCompositionalLayoutConfiguration()
        config.interSectionSpacing = 10
        layout.configuration = config
        
        return layout
    }
    
    enum Section: Int, Hashable, CaseIterable {
        /// The item preview, ie, the image or color's view
        case itemPreview
        
        /// Actions to do, such as saving the image if available
        case itemActions
        
        /// The item information, in a list layout
        case itemInfo
        
        /// The item information that is specific to it's type,
        /// ie, the red, green and blue components of a color
        case specificTypeInfo
        
        /// The information specifically related to the rendition,
        /// coming from CUIRenditionKey
        case renditionInformation
    }
    
    enum ItemType: Hashable {
        case preview
        case action(ItemAction)
        case details(DetailItem)
        
        static func fromDetails(_ details: [DetailItem]) -> [ItemType] {
            return details.map { details in
                ItemType.details(details)
            }
        }
    }
    
    struct DetailItem: Hashable {
        /// The text of the primary label, ie "Height"
        let primaryText: String
        
        /// The text of the secondary label, ie, the height number as a String
        let secondaryText: String
        
        init(primaryText: String, secondaryText: String?) {
            self.primaryText = primaryText
            self.secondaryText = secondaryText ?? "N/A"
        }
        
        init<DetailTextType: CustomStringConvertible>(primaryText: String, secondaryText: DetailTextType?) {
            self.primaryText = primaryText
            self.secondaryText = secondaryText?.description ?? "N/A"
        }
    }
    
    struct ItemAction: Hashable {
        static func == (lhs: ItemAction, rhs: ItemAction) -> Bool {
            return lhs.displayText == rhs.displayText
        }
        
        let displayText: String
        let displayImage: UIImage?
        let action: (() -> Void)
        
        func hash(into hasher: inout Hasher) {
            hasher.combine(displayText)
            hasher.combine(displayImage)
        }
    }
}

extension AssetCatalogRenditionViewController: UICollectionViewDelegate, UICollectionViewDragDelegate {
    func collectionView(_ collectionView: UICollectionView, contextMenuConfigurationForItemAt indexPath: IndexPath, point: CGPoint) -> UIContextMenuConfiguration? {
        UIContextMenuConfiguration(identifier: nil, previewProvider: nil) { [self] _ in
            let item = dataSource.itemIdentifier(for: indexPath)
            switch item {
            case .action(let itemAction):
                let menuAction = UIAction(title: itemAction.displayText, image: itemAction.displayImage) { _ in
                    itemAction.action()
                }
                
                return UIMenu(children: [menuAction])
            case .details(let detail):
                let menuAction = UIAction(title: "Copy", image: UIImage(systemName: "doc.on.doc")) { _ in
                    UIPasteboard.general.string = detail.secondaryText
                }
                
                return UIMenu(children: [menuAction])
            default:
                return nil
            }
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, shouldHighlightItemAt indexPath: IndexPath) -> Bool {
        switch dataSource.itemIdentifier(for: indexPath) {
        case .action(_): return true
        default: return false
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        switch dataSource.itemIdentifier(for: indexPath) {
        case .action(let action): action.action()
        default: break
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, itemsForBeginning session: UIDragSession, at indexPath: IndexPath) -> [UIDragItem] {
        // here, we are dragging the preview item displayed
        // which is in the first section
        guard indexPath.section == 0, let dragItem = rendition.makeDragItem() else { return [] }
        
        // (if we can) get the cell that is being dragged, set the previewProvider properly
        // otherwise funky behaviour arises
        if let cell = collectionView.cellForItem(at: indexPath) as? AssetCatalogGridPreviewCell {
            dragItem.previewProvider = {
                let params = UIDragPreviewParameters()
                params.backgroundColor = .clear
                return UIDragPreview(view: cell.previewView, parameters: params)
            }
        }
        
        return [
            dragItem
        ]
    }
}
