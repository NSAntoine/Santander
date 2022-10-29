//
//  AssetCatalogSidebarListView.swift
//  Santander
//
//  Created by Serena on 27/10/2022
//


import UIKit
import AssetCatalogWrapper

class AssetCatalogSidebarListView: UIViewController {
    
    enum Section: Hashable {
        case main
    }
    
    typealias DataSource = UICollectionViewDiffableDataSource<Section, RenditionType>
    typealias Snapshot = NSDiffableDataSourceSnapshot<Section, RenditionType>
    typealias CellRegistration = UICollectionView.CellRegistration<UICollectionViewListCell, RenditionType>
    
    let catalogController: AssetCatalogViewController
    
    var collectionView: UICollectionView!
    var dataSource: DataSource!
    
    lazy var sections: [RenditionType] = []
    
    init(catalogController: AssetCatalogViewController) {
        self.catalogController = catalogController
        
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        makeCollectionView()
        makeDataSource()
        addItems()
        
        splitViewController?.setViewController(catalogController, for: .secondary)
        
        title = catalogController.fileURL.deletingPathExtension().lastPathComponent
        navigationController?.navigationBar.prefersLargeTitles = true
    }
    
    func makeCollectionView() {
        let layout = UICollectionViewCompositionalLayout { _, env in
            return .list(using: UICollectionLayoutListConfiguration(appearance: .sidebar), layoutEnvironment: env)
        }
        
        collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        collectionView.delegate = self
        view.addSubview(collectionView)
        
        collectionView.constraintCompletely(to: view)
    }
    
    func makeDataSource() {
        
        let cellRegistration = CellRegistration { cell, indexPath, itemIdentifier in
            var conf = cell.defaultContentConfiguration()
            conf.text = itemIdentifier.description
            conf.image = itemIdentifier.displayImage
            cell.contentConfiguration = conf
        }
        
        self.dataSource = DataSource(collectionView: collectionView) { collectionView, indexPath, itemIdentifier in
            return collectionView.dequeueConfiguredReusableCell(using: cellRegistration, for: indexPath, item: itemIdentifier)
        }
    }
    
    func addItems() {
        var snapshot = Snapshot()
        snapshot.appendSections([.main])
        snapshot.appendItems(sections, toSection: .main)
        dataSource.apply(snapshot)
    }
}

extension AssetCatalogSidebarListView: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        catalogController.collectionView.scrollToItem(at: IndexPath(row: 0, section: indexPath.row), at: .top, animated: true)
    }
}

fileprivate extension RenditionType {
    var displayImage: UIImage? {
        switch self {
        case .image, .svg:
            return UIImage(systemName: "photo")
        case .icon:
            return UIImage(systemName: "app")
        case .imageSet:
            return UIImage(systemName: "photo.stack")
        case .multiSizeImageSet:
            return UIImage(systemName: "cube.box")
        case .pdf:
            return UIImage(systemName: "doc.richtext")
        case .color:
            return UIImage(systemName: "paintbrush")
        case .rawData:
            return UIImage(systemName: "text.quote")
        case .unknown:
            return UIImage(systemName: "questionmark.app")
        }
    }
}
