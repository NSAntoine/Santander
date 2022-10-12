//
//  AssetCatalogViewController.swift
//  Santander
//
//  Created by Serena on 16/09/2022
//


import UIKit
import CoreUIBridge
import UniformTypeIdentifiers
import PhotosUI

#warning("Also make a view for displaying information about this catalog and display it above the collection view")
class AssetCatalogViewController: UIViewController {
    typealias DataSource = UICollectionViewDiffableDataSource<RenditionType, Rendition>
    typealias SupplementaryRegistration = UICollectionView.SupplementaryRegistration<AssetCatalogSectionHeader>
    typealias CellRegistration = UICollectionView.CellRegistration<AssetCatalogCell, Rendition>
    
    static let titleElementKind = "RenditionTypeTitle"
    
    let fileURL: URL
    var renditionCollection: RenditionCollection
    var catalog: CUICatalog
    fileprivate var editorDelegate: AssetCatalogControllerItemEditorDelegate?
    
    var collectionView: UICollectionView!
    var dataSource: DataSource!
    var noResultsLabel: UILabel = UILabel()
    
    init(renditions: RenditionCollection, fileURL: URL, catalog: CUICatalog) {
        self.renditionCollection = renditions
        self.fileURL = fileURL
        
        self.catalog = catalog
        
        super.init(nibName: nil, bundle: nil)
    }
    
    convenience init(catalogFileURL fileURL: URL) throws {
        let (catalog, renditions) = try AssetCatalogWrapper.shared.renditions(forCarArchive: fileURL)
        self.init(renditions: renditions, fileURL: fileURL, catalog: catalog)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.backgroundColor = .systemBackground
        
        let filename = fileURL.deletingPathExtension()
        title = filename.lastPathComponent
        navigationController?.navigationBar.prefersLargeTitles = true
        navigationItem.hidesSearchBarWhenScrolling = false
        
        let searchController = UISearchController()
        searchController.searchBar.delegate = self
        navigationItem.searchController = searchController
        
        configureCollectionView()
        configureDataSource()
        
        setupBarItems()
    }
    
    
    func configureCollectionView() {
        self.collectionView = UICollectionView(frame: .zero, collectionViewLayout: createLayout())
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        collectionView.dragDelegate = self
        collectionView.delegate = self
        
        view.addSubview(collectionView)
        
        collectionView.constraintCompletely(to: view)
    }
    
    func makeLeftItemMenu() -> UIMenu {
        let extractAction = UIAction(title: "Extract to..") { _ in
            self.extractAction()
        }
        
        return UIMenu(children: [extractAction])
    }
    
    func setupBarItems() {
        let dismissAction = UIAction { _ in
            self.dismiss(animated: true)
        }
        
        navigationItem.rightBarButtonItem = UIBarButtonItem(systemItem: .close, primaryAction: dismissAction)
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            image: UIImage(systemName: "ellipsis.circle"),
            menu: makeLeftItemMenu()
        )
    }
    
    func extractAction() {
        let action: PathSelectionOperation = .custom(description: "extract", verbDescription: "Extracting to..") { [self] operationVC, selectedPath in
            let extractionPath = selectedPath
                .appendingPathComponent("\(fileURL.lastPathComponent)-Extracted")
            extractItems(extractionPath: extractionPath, sourceVC: operationVC) { result in
                switch result {
                case .failure(let failure):
                    let cancelAction: UIAlertAction = .cancel(handler: {
                        operationVC.dismiss(animated: true)
                    }, title: "OK")
                    operationVC.errorAlert(failure, title: "Unable to extract items", cancelAction: cancelAction)
                default:
                    operationVC.dismiss(animated: true)
                }
            }
        }
        
        let vc = PathOperationViewController(paths: [fileURL], operationType: action)
        present(UINavigationController(rootViewController: vc), animated: true) {
            // go to .car's parent path once the operation vc is presented
            vc.goToPath(path: self.fileURL.deletingLastPathComponent())
        }
    }
    
    func extractItems(
        extractionPath savePath: URL,
        sourceVC: UIViewController,
        completionHandler: @escaping (Result<Void, Error>) -> Void
    ) {
        do {
            try FSOperation.perform(.createDirectory, url: savePath)
        } catch {
            return completionHandler(.failure(error))
        }
        
        let alertController = UIAlertController(title: "Extracting..", message: nil, preferredStyle: .alert)
        let spinner = UIActivityIndicatorView()
        spinner.translatesAutoresizingMaskIntoConstraints = false
        spinner.startAnimating()
        alertController.view.addSubview(spinner)
        
        NSLayoutConstraint.activate([
            alertController.view.heightAnchor.constraint(equalToConstant: 95),
            spinner.centerXAnchor.constraint(equalTo: alertController.view.centerXAnchor),
            spinner.bottomAnchor.constraint(equalTo: alertController.view.bottomAnchor, constant: -20),
        ])
        
        sourceVC.present(alertController, animated: true)
        let justRenditions = renditionCollection.flatMap(\.renditions)
        // key: the item name
        // value: why it failed
        var failedItems: [String: String] = [:]
        
        DispatchQueue.global(qos: .userInitiated).async {
            for rendition in justRenditions {
                let name = rendition.name
                let itemURL = savePath.appendingPathComponent(name)
                
                if let image = rendition.image {
                    var type = UTType(filenameExtension: (name as NSString).pathExtension) ?? .png
                    // if the type isn't declared, such as for packet assets, just use PNG
                    if !type.isDeclared { type = .png }
                    
                    guard let dest = CGImageDestinationCreateWithURL(itemURL as CFURL, type.identifier as CFString, 1, nil) else {
                        failedItems[name] = "Failed to generate image for item"
                        continue
                    }
                    
                    CGImageDestinationAddImage(dest, image, nil)
                    if !CGImageDestinationFinalize(dest) {
                        failedItems[name] = "Failed to write image to file"
                    }
                    
                } else if let data = rendition.cuiRend.srcData {
                    do {
                        try data.write(to: itemURL)
                    } catch {
                        failedItems[name] = "Failed to write item data to file: \(error.localizedDescription)"
                    }
                }
            }
            
            DispatchQueue.main.async {
                alertController.dismiss(animated: true)
                
                if !failedItems.isEmpty {
                    return completionHandler(.failure(_ExtractErrors.failedToExtractCatalog(failedItems: failedItems)))
                } else {
                    return completionHandler(.success(()))
                }
            }
        }
        
    }
}

// Mark: - Layout & Data Source stuff
extension AssetCatalogViewController: UICollectionViewDelegate {
    func createLayout() -> UICollectionViewLayout {
        let itemSize = NSCollectionLayoutSize(
                widthDimension: .fractionalWidth(1),
                heightDimension: .fractionalHeight(0.40)
            )
        
        let layoutItem = NSCollectionLayoutItem(layoutSize: itemSize)
        layoutItem.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 5, bottom: 0, trailing: 5)
        layoutItem.contentInsets.bottom = 3
        
        let layoutGroupSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(0.93),
            heightDimension: .fractionalWidth(0.55)
        )
        
        let layoutGroup: NSCollectionLayoutGroup = .vertical(
            layoutSize: layoutGroupSize,
            subitem: layoutItem,
            count: 3
        )
        
        layoutGroup.interItemSpacing = .fixed(15)
        
        
        let layoutSection = NSCollectionLayoutSection(group: layoutGroup)
        layoutSection.orthogonalScrollingBehavior = .groupPagingCentered
        
        let titleHeaderSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(0.93),
            heightDimension: .absolute(50)
        )
        
        let titleSupplementary = NSCollectionLayoutBoundarySupplementaryItem(
            layoutSize: titleHeaderSize,
            elementKind: AssetCatalogViewController.titleElementKind,
            alignment: .top
        )
        
        layoutSection.boundarySupplementaryItems = [titleSupplementary]
        
        let layout = UICollectionViewCompositionalLayout(section: layoutSection)
        let config = UICollectionViewCompositionalLayoutConfiguration()
        
        config.interSectionSpacing = 20
        layout.configuration = config
        return layout
    }
    
    
    func configureDataSource() {
        let cellRegistration = CellRegistration { cell, indexPath, itemIdentifier in
            cell.rendition = itemIdentifier
            cell.configure()
        }
        
        dataSource = DataSource(collectionView: collectionView) { collectionView, indexPath, itemIdentifier in
            return collectionView.dequeueConfiguredReusableCell(using: cellRegistration, for: indexPath, item: itemIdentifier)
        }
        
        updateDataSourceItems(collection: renditionCollection)
        
        let supplementaryRegistration = SupplementaryRegistration(elementKind: AssetCatalogViewController.titleElementKind) { supplementaryView, elementKind, indexPath in
            let snapshot = self.dataSource.snapshot()
            let section = snapshot.sectionIdentifiers[indexPath.section]
            supplementaryView.configure(withSection: section, snapshot: snapshot, sender: self)
        }
        
        dataSource.supplementaryViewProvider = { (collectionView, string, indexPath) in
            return collectionView.dequeueConfiguredReusableSupplementary(using: supplementaryRegistration, for: indexPath)
        }
    }
    
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard let item = dataSource.itemIdentifier(for: indexPath) else { return }
        let vc = AssetCatalogRenditionViewController(rendition: item)
        present(UINavigationController(rootViewController: vc), animated: true)
    }
    
    func collectionView(_ collectionView: UICollectionView, contextMenuConfigurationForItemAt indexPath: IndexPath, point: CGPoint) -> UIContextMenuConfiguration? { 
        guard let item = dataSource.itemIdentifier(for: indexPath) else { return nil }
        return UIContextMenuConfiguration(identifier: nil, previewProvider: nil) { _ in
            let copyNameAction = UIAction(title: "Copy name", image: UIImage(systemName: "doc.on.doc")) { _ in
                UIPasteboard.general.string = item.name
            }
            var children = [copyNameAction]
            
            if let image = item.image {
                let copyImageAction = UIAction(title: "Copy Image") { _ in
                    UIPasteboard.general.image = UIImage(cgImage: image)
                }
                
                children.append(copyImageAction)
            }
            
            var attributes: UIMenuElement.Attributes = []
            
            // can only edit images & icons for now
            // i tried to get color editing to work but for whatever reason
            // -[CUIMutableCommonAssetStorage setColor:forName:excludeFromFilter:] just doesn't work..
            if !item.type.isEditable {
                attributes.insert(.disabled)
            }
            
            let editAction = UIAction(title: "Edit", attributes: attributes) { _ in
                self.editItem(item)
            }
            
            children.append(editAction)
            
            
            let deleteItemAction = UIAction(title: "Delete", image: UIImage(systemName: "trash"), attributes: .destructive) { [self] _ in
                do {
                    try catalog.removeItem(item, fileURL: fileURL)
                    
                    // update the catalog and rendition collection
                    let (newCatalog, newRenditions) = try AssetCatalogWrapper.shared.renditions(forCarArchive: fileURL)
                    self.catalog = newCatalog
                    self.renditionCollection = newRenditions
                    updateDataSourceItems(collection: renditionCollection)
                } catch {
                    errorAlert(error, title: "Unable to delete items and update file")
                }
            }
            
            children.append(deleteItemAction)
            
            return UIMenu(children: children)
        }
        
    }
    
    func updateDataSourceItems(collection: RenditionCollection) {
        var snapshot = NSDiffableDataSourceSnapshot<RenditionType, Rendition>()
        for (section, items) in collection {
            snapshot.appendSections([section])
            snapshot.appendItems(items, toSection: section)
        }
        
        dataSource.apply(snapshot, animatingDifferences: true)
    }
    
    func editItem(_ item: Rendition) {
        guard let preview = item.preview else { return }
        
        editorDelegate = AssetCatalogControllerItemEditorDelegate(sender: self, selectedRendition: item)
        let vc: UIViewController
        switch preview {
        case .image(_):
            var conf = PHPickerConfiguration()
            conf.filter = .images
            conf.selectionLimit = 1
            let photoVC = PHPickerViewController(configuration: conf)
            photoVC.delegate = editorDelegate
            vc = photoVC
        case .color(_):
            let colorVC = UIColorPickerViewController()
            colorVC.delegate = editorDelegate
            vc = colorVC
        }
        
        present(vc, animated: true)
    }
}

extension AssetCatalogViewController: UICollectionViewDragDelegate {
    func collectionView(_ collectionView: UICollectionView, itemsForBeginning session: UIDragSession, at indexPath: IndexPath) -> [UIDragItem] {
        guard let dragItem = dataSource.itemIdentifier(for: indexPath)?.makeDragItem() else { return [] }
        
        return [
            dragItem
        ]
    }
    
}

extension AssetCatalogViewController: UISearchBarDelegate {
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        noResultsLabel.removeFromSuperview()
        guard !searchText.isEmpty else {
            updateDataSourceItems(collection: renditionCollection) // if the text is empty, show all items
            return
        }
        
        let newCollection = renditionCollection.map { (type, renditions) in
            let newRenditions = renditions.filter { rend in
                return rend.name.localizedCaseInsensitiveContains(searchText)
            }
            
            return (type, newRenditions)
        }.filter { (_, rends) in
            !rends.isEmpty
        }
        
        updateDataSourceItems(collection: newCollection)
        
        // if there are no search results & the noResultsLabel isn't already being displayed
        // display it
        if newCollection.isEmpty, noResultsLabel.superview == nil {
            noResultsLabel.text = "No Results"
            noResultsLabel.font = .systemFont(ofSize: 20, weight: .bold)
            noResultsLabel.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview(noResultsLabel)
            
            let guide = view.layoutMarginsGuide
            NSLayoutConstraint.activate([
                noResultsLabel.centerXAnchor.constraint(equalTo: guide.centerXAnchor),
                noResultsLabel.centerYAnchor.constraint(equalTo: guide.centerYAnchor)
            ])
        }
    }
    
    func searchBarCancelButtonClicked(_ searchBar: UISearchBar) {
        noResultsLabel.removeFromSuperview()
        updateDataSourceItems(collection: renditionCollection)
    }
    
    func fetchItemsFromFile() {
        do {
            let (newCatalog, newCollection) = try AssetCatalogWrapper.shared.renditions(forCarArchive: fileURL)
            self.catalog = newCatalog
            self.renditionCollection = newCollection
            updateDataSourceItems(collection: renditionCollection)
        } catch {
            let cancelAction = UIAlertAction(title: "Dismiss", style: .cancel) { _ in
                self.dismiss(animated: true)
            }
            
            errorAlert(error, title: "Unable to update items", presentingFromIfAvailable: nil, cancelAction: cancelAction)
        }
    }
    
}

/// A class which acts as a delegate for the Photo / Color controllers when editing an item
///  rom AssetCatalogViewController
class AssetCatalogControllerItemEditorDelegate: NSObject, PHPickerViewControllerDelegate, UIColorPickerViewControllerDelegate {
    
    let sender: AssetCatalogViewController
    // The rendition to edit to this photo
    let selectedRendition: Rendition
    
    init(sender: AssetCatalogViewController, selectedRendition: Rendition) {
        self.sender = sender
        self.selectedRendition = selectedRendition
        super.init()
    }
    
    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        picker.dismiss(animated: true)
        guard let first = results.first else { return }
        first.itemProvider.loadObject(ofClass: UIImage.self) { [self] image, error in
            guard let image = image as? UIImage, let cgImage = image.cgImage else {
                sender.errorAlert("Unable to acquire image selected", title: "Unable to edit item")
                return
            }
            
            edit(to: .image(cgImage))
        }
    }
    
    func colorPickerViewControllerDidFinish(_ viewController: UIColorPickerViewController) {
        edit(to: .color(viewController.selectedColor.cgColor))
    }
    
    func edit(to newItem: RenditionPreview) {
        DispatchQueue.main.async { [self] in
            do {
                try sender.catalog.editItem(selectedRendition, fileURL: sender.fileURL, to: newItem)
                sender.fetchItemsFromFile()
            } catch {
                sender.errorAlert(error, title: "Unable to edit item")
            }
        }
    }
    
}

fileprivate
enum _ExtractErrors: Error, LocalizedError {
    case failedToExtractCatalog(failedItems: [String: String])
    
    var errorDescription: String? {
        switch self {
        case .failedToExtractCatalog(let failedItems):
            var message = ""
            for (item, itemMessage) in failedItems {
                message.append("\(item): \(itemMessage)")
            }
            return message
        }
    }
}
