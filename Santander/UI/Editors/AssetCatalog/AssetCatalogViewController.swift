//
//  AssetCatalogViewController.swift
//  Santander
//
//  Created by Serena on 16/09/2022
//


import UIKit
import AssetCatalogWrapper
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
    var layoutMode: LayoutMode = LayoutMode(UserPreferences.assetCatalogControllerLayoutMode) {
        didSet {
            collectionView.setCollectionViewLayout(createLayout(), animated: true)
            UserPreferences.assetCatalogControllerLayoutMode = layoutMode.rawValue
        }
    }
    
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
    
    
    // scroll up or down keyboard shortcuts
    override var keyCommands: [UIKeyCommand]? {
        return [
            UIKeyCommand(title: "Scroll Up", action: #selector(goUpOrDown(sender:)), input: UIKeyCommand.inputUpArrow, modifierFlags: .command),
            UIKeyCommand(title: "Scroll Down", action: #selector(goUpOrDown(sender:)), input: UIKeyCommand.inputDownArrow, modifierFlags: .command)
        ]
    }
    
    @objc
    func goUpOrDown(sender: UIKeyCommand) {
        switch sender.input {
        case UIKeyCommand.inputDownArrow:
            let snapshot = dataSource.snapshot()
            if let last = snapshot.sectionIdentifiers.last {
                let section = snapshot.sectionIdentifiers.count
                let row = snapshot.itemIdentifiers(inSection: last).count
                collectionView.scrollToItem(at: IndexPath(row: row - 1, section: section - 1), at: .bottom, animated: true)
            }
        case UIKeyCommand.inputUpArrow:
            collectionView.scrollToItem(at: IndexPath(row: 0, section: 0), at: .top, animated: true)
        default:
            break
        }
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
        
        let changeLayoutActions = LayoutMode.allCases.map { [self] mode in
            return UIAction(title: mode.description, state: layoutMode == mode ? .on : .off) { [self] _ in
                layoutMode = mode
                setupBarItems() // update the bar items so that the new selected mode is marked with a checkmark
            }
        }
        
        let changeLayoutMenu = UIMenu(title: "Layout", children: changeLayoutActions)
        return UIMenu(children: [extractAction, changeLayoutMenu])
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
                    operationVC.errorAlert(failure, title: "Unable to extract items")
                default:
                    operationVC.dismiss(animated: true)
                }
            }
        }
        
        let vc = PathOperationViewController(paths: [fileURL], operationType: action, dismissWhenDone: false)
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
        var caughtError: Error? = nil
        
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try FSOperation.perform(.extractCatalog(renditions: justRenditions.toCodable(), resultPath: savePath), rootHelperConf: RootConf.shared)
            } catch {
                caughtError = error
            }

        }

        DispatchQueue.main.async {
            alertController.dismiss(animated: true) {
                if let caughtError = caughtError {
                    return completionHandler(.failure(caughtError))
                } else {
                    return completionHandler(.success(()))
                }
            }
        }
    }
    
    enum LayoutMode: Int, CustomStringConvertible, CaseIterable {
        case horizantal
        case verical
        
        init(_ rawValue: Int) {
            // default to horizontal
            switch rawValue {
            case LayoutMode.verical.rawValue: self = .verical
            default: self = .horizantal
            }
        }
        
        var description: String {
            switch self {
            case .horizantal:
                return "Horizontal"
            case .verical:
                return "Vertical"
            }
        }
    }
}

// Mark: - Layout & Data Source stuff
extension AssetCatalogViewController: UICollectionViewDelegate {
    func createLayout() -> UICollectionViewLayout {
        let section: NSCollectionLayoutSection
        
        switch layoutMode {
        case .verical:
            let itemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0),
                                                  heightDimension: .fractionalHeight(1.0))
            let item = NSCollectionLayoutItem(layoutSize: itemSize)
            let groupSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0),
                                                   heightDimension: .absolute(60))
            
            let group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, subitem: item, count: 1)
            let spacing = CGFloat(10)
            group.interItemSpacing = .fixed(10)
            
            section = NSCollectionLayoutSection(group: group)
            section.interGroupSpacing = spacing
            section.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 10, bottom: 0, trailing: 10)
        case .horizantal:
            let itemSize = NSCollectionLayoutSize(
                widthDimension: .fractionalWidth(1),
                heightDimension: .fractionalHeight(0.40)
            )
            
            let layoutItem = NSCollectionLayoutItem(layoutSize: itemSize)
            layoutItem.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 5, bottom: 3, trailing: 5)
            
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
            
            section = NSCollectionLayoutSection(group: layoutGroup)
            section.orthogonalScrollingBehavior = .groupPagingCentered
        }
        
        let titleHeaderSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(0.93),
            heightDimension: .absolute(50)
        )
        
        let titleSupplementary = NSCollectionLayoutBoundarySupplementaryItem(
            layoutSize: titleHeaderSize,
            elementKind: AssetCatalogViewController.titleElementKind,
            alignment: layoutMode == .horizantal ? .top : .topLeading
        )
        
        section.boundarySupplementaryItems = [titleSupplementary]
        let layout = UICollectionViewCompositionalLayout(section: section)
        let conf = UICollectionViewCompositionalLayoutConfiguration()
        conf.interSectionSpacing = 20
        
        layout.configuration = conf
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
                let uiImage = UIImage(cgImage: image)
                let copyImageAction = UIAction(title: "Copy Image") { _ in
                    UIPasteboard.general.image = uiImage
                }
                
                children.append(copyImageAction)
                
                let saveImageAction = UIAction(title: "Save Image", image: UIImage(systemName: "square.and.arrow.down")) { _ in
                    UIImageWriteToSavedPhotosAlbum(uiImage, self, #selector(self.didSaveImage(_:error:context:)), nil)
                }
                
                children.append(saveImageAction)
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
    
    @objc
    func didSaveImage(_ im: UIImage, error: Error?, context: UnsafeMutableRawPointer?) {
        if let error = error {
            errorAlert(error, title: "Unable to save image")
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
                message.append("\(item): \(itemMessage)\n")
            }
            return message.trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }
}
