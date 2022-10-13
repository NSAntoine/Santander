//
//  PathSidebarListViewController.swift
//  Santander
//
//  Created by Serena on 25/06/2022
//
	

import UIKit

class PathSidebarListViewController: UIViewController, PathTransitioning, UICollectionViewDelegate {
    typealias DataSource = UICollectionViewDiffableDataSource<String, ItemType>
    typealias CellRegistration = UICollectionView.CellRegistration<UICollectionViewListCell, ItemType>
    
    var dataSource: DataSource!
    var pathGroups = UserPreferences.pathGroups
    var collectionView: UICollectionView!
    
    /// The view controller in the secondary column displaying the path list
    var subPathsSecondary: SubPathsTableViewController? {
        splitViewController?.viewController(for: .secondary) as? SubPathsTableViewController
    }
    
    init() {
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        title = "Santander"
        setupCollectionView()
        setupDataSource()
        
        let newGroupAction = UIAction {
            self.presentNewGroupAlert()
        }
        
        let newGroupsButton = UIBarButtonItem(systemItem: .add, primaryAction: newGroupAction)
        setToolbarItems([newGroupsButton], animated: true)
        navigationController?.setToolbarHidden(false, animated: false)
        
        NotificationCenter.default.addObserver(forName: .pathGroupsDidChange, object: nil, queue: nil) { [self] notif in
            if let newGroups = notif.object as? [PathGroup] {
                self.pathGroups = newGroups
                addItems()
            }
        }
        
    }
    
    func setupCollectionView() {
        let layout = UICollectionViewCompositionalLayout { _, env in
            var layoutConf = UICollectionLayoutListConfiguration(appearance: .insetGrouped)
            layoutConf.headerMode = .firstItemInSection
            layoutConf.trailingSwipeActionsConfigurationProvider = { indexPath in
                let removeAction = UIContextualAction(style: .destructive, title: nil) { _, _, completion in
                    // remove the item
                    var newPathGroups = self.pathGroups
                    var currentGroup = newPathGroups[indexPath.section]
                    currentGroup.paths.remove(at: indexPath.row - 1)
                    newPathGroups[indexPath.section] = currentGroup
                    UserPreferences.pathGroups = newPathGroups
                    completion(true)
                }
                
                removeAction.image = .remove
                return UISwipeActionsConfiguration(actions: [removeAction])
            }
            
            return .list(using: layoutConf, layoutEnvironment: env)
        }
        
        self.collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        collectionView.delegate = self
        
        view.addSubview(collectionView)
        collectionView.constraintCompletely(to: view)
    }
    
    func setupDataSource() {
        let cellRegistration = CellRegistration { cell, indexPath, itemIdentifier in
            var conf: UIListContentConfiguration
            switch itemIdentifier {
            case .header(let headerTitle):
                conf = .sidebarHeader()
                conf.text = headerTitle
                cell.accessories = [.outlineDisclosure()]
            case .path(let path):
                conf = cell.defaultContentConfiguration()
                conf.text = path.lastPathComponent
                conf.image = path.displayImage
            }
            
            cell.contentConfiguration = conf
        }
        
        dataSource = DataSource(collectionView: collectionView) { collectionView, indexPath, item in
            return collectionView.dequeueConfiguredReusableCell(using: cellRegistration, for: indexPath, item: item)
        }
        
        addItems()
    }
    
    func addItems() {
        var snapshot = NSDiffableDataSourceSnapshot<String, ItemType>()
        let justSections = pathGroups.map(\.name)
        snapshot.appendSections(justSections)
        dataSource.apply(snapshot, animatingDifferences: false)
        
        for group in pathGroups {
            var sectionSnapshot = NSDiffableDataSourceSectionSnapshot<ItemType>()
            let header: ItemType = .header(group.name)
            sectionSnapshot.append([header])
            
            let paths = ItemType.fromPaths(group.paths)
            sectionSnapshot.append(paths, to: header)
            sectionSnapshot.expand([header])
            dataSource.apply(sectionSnapshot, to: group.name)
        }
    }
    
    func goToPath(path: URL) {
        let secondary = subPathsSecondary
        if let currentSubpathsPath = secondary?.currentPath {
            // make sure we're not going to a directory that the secondary column is already showing
            // or is a subpath of
            guard currentSubpathsPath != path else { return }
            
            // this is triggered if, for example, we're in /var/jb/tweaks and we pressed on the button
            // to go to /var or /var/jb
            // then we pop to the view controller rather than creating new ones
            if currentSubpathsPath.path.hasPrefix(path.path) {
                if let vcs = secondary?.navigationController?.viewControllers as? [SubPathsTableViewController],
                   let first = vcs.first(where: { $0.currentPath == path }) {
                       secondary?.navigationController?.popToViewController(first, animated: true)
                }
            } else if path.deletingLastPathComponent() != currentSubpathsPath {
                // if we're going to a path that has multiple parents after the current path
                // ie, going to /var/mobile/Media from /var
                // call the traverse function
                secondary?.traverseThroughPath(path)
            } else {
                // if we're going to a path that is directly a
                splitViewController?.setViewController(SubPathsTableViewController(path: path), for: .secondary)
            }
            
        } else {
            let vc = SubPathsTableViewController(path: .root)
            splitViewController?.setViewController(vc, for: .secondary)
            if path != .root { subPathsSecondary?.traverseThroughPath(path) }
        }
    }
    
    enum ItemType: Hashable {
        case header(String)
        case path(URL)
        
        static func fromPaths(_ paths: [URL]) -> [ItemType] {
            return paths.map { path in
                ItemType.path(path)
            }
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard let item = dataSource.itemIdentifier(for: indexPath) else { return }
        switch item {
        case .header(_): break // shouldn't get here
        case .path(let path):
            goToPath(path: path)
        }
    }
    
    func presentNewGroupAlert() {
        let alert = UIAlertController(title: "New Group", message: nil, preferredStyle: .alert)
        alert.addTextField { textField in
            textField.placeholder = "Group name.."
        }
        
        let addAction = UIAlertAction(title: "Add", style: .default) { [self] _ in
            guard let name = alert.textFields?.first?.text else { return }
            if pathGroups.map(\.name).contains(name) {
                errorAlert("Group with same name already exists", title: "Unable to create Group with name \(name)")
            }
            
            let newGroup = PathGroup(name: name, paths: [])
            UserPreferences.pathGroups.append(newGroup)
        }
        
        alert.addAction(addAction)
        alert.addAction(.cancel())
        present(alert, animated: true)
    }
}
