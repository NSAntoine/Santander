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
    typealias GridPreviewCellRegistration = UICollectionView.CellRegistration<AssetCatalogGridPreviewCell, Rendition>
    
    let rendition: Rendition
    var collectionView: UICollectionView!
    var dataSource: DataSource!
    
    init(rendition: Rendition) {
        self.rendition = rendition
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
    
    func configureDataSource() {
        let detailCellRegistration = DetailCellRegistration { cell, indexPath, details in
            var content = UIListContentConfiguration.cell()
            content.prefersSideBySideTextAndSecondaryText = true
            content.text = details.primaryText
            content.secondaryText = details.secondaryText
            content.secondaryTextProperties.font = .preferredFont(forTextStyle: .footnote)
            cell.contentConfiguration = content
            var background = UIBackgroundConfiguration.listAccompaniedSidebarCell()
            background.cornerRadius = 8
            
            switch self.traitCollection.userInterfaceStyle {
            case .light:
                background.backgroundColor = .tertiarySystemBackground
            case .dark:
                background.backgroundColor = .systemFill
            default: break
            }
            
            background.strokeColor = .systemGray3
            background.strokeWidth = 1.0 / cell.traitCollection.displayScale
            cell.backgroundConfiguration = background
        }
        
        let previewCellRegistration = GridPreviewCellRegistration { cell, indexPath, itemIdentifier in
            cell.rendition = self.rendition
            cell.configure()
        }
        
        self.dataSource = DataSource(collectionView: collectionView) { collectionView, indexPath, itemIdentifier in
            switch itemIdentifier {
            case .details(let detailItem):
                return collectionView.dequeueConfiguredReusableCell(using: detailCellRegistration, for: indexPath, item: detailItem)
            case .preview:
                return collectionView.dequeueConfiguredReusableCell(using: previewCellRegistration, for: indexPath, item: self.rendition)
            }
        }
    }
    
    func addItems() {
        var snapshot = NSDiffableDataSourceSnapshot<Section, ItemType>()
        snapshot.appendSections([.itemPreview, .itemInfo, .renditionInformation])
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
        
        snapshot.appendItems(ItemType.fromDetails(rendInfo), toSection: .renditionInformation)
        
        snapshot.appendItems([.preview], toSection: .itemPreview)
        snapshot.appendItems(ItemType.fromDetails(itemDetails), toSection: .itemInfo)
        
        switch rendition.preview {
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
            
            snapshot.appendSections([.specificTypeInfo])
            snapshot.appendItems(ItemType.fromDetails(colorDetails), toSection: .specificTypeInfo)
        default:
            break
        }
        dataSource.apply(snapshot)
    }
    
    func makeLayout() -> UICollectionViewLayout {
        let layout = UICollectionViewCompositionalLayout { sectionIndex, enviroment in
            let section = Section(rawValue: sectionIndex)!
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
        
        init<TextType: CustomStringConvertible>(primaryText: String, secondaryText: TextType?) {
            self.primaryText = primaryText
            self.secondaryText = secondaryText?.description ?? "N/A"
        }
    }
}

extension AssetCatalogRenditionViewController: UICollectionViewDelegate, UICollectionViewDragDelegate {
    func collectionView(_ collectionView: UICollectionView, contextMenuConfigurationForItemAt indexPath: IndexPath, point: CGPoint) -> UIContextMenuConfiguration? {
        UIContextMenuConfiguration(identifier: nil, previewProvider: nil) { [self] _ in
            guard let cell = dataSource.collectionView(collectionView, cellForItemAt: indexPath) as? UICollectionViewListCell else {
                return nil
            }
            
            var items: [UIAction] = []
            
            // if we can get the text value (secondaryText) displayed, then add
            // an option to copy it
            if let text = (cell.contentConfiguration as? UIListContentConfiguration)?.secondaryText {
                let copyAction = UIAction(title: "Copy", image: UIImage(systemName: "doc.on.doc")) { _ in
                    UIPasteboard.general.string = text
                }
                
                items.append(copyAction)
            }
            
            return UIMenu(children: items)
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, shouldHighlightItemAt indexPath: IndexPath) -> Bool {
        return false
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
