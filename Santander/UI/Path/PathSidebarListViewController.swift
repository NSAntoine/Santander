//
//  PathSidebarListViewController.swift
//  Santander
//
//  Created by Serena on 25/06/2022
//
	

import UIKit

#warning("Make a view controller to create a new group")
class PathSidebarListViewController: UIViewController, PathTransitioning, UICollectionViewDelegate {
    
    typealias Item = DiffableDataSourceItem<String, Path>
    typealias DataSource = UICollectionViewDiffableDataSource<String, Item>
    typealias CellRegistration = UICollectionView.CellRegistration<UICollectionViewListCell, Item>
    
    var dataSource: DataSource!
    var pathGroups = UserPreferences.pathGroups
    var collectionView: UICollectionView!
    
    /// The view controller in the secondary column displaying the path list
    var subPathsSecondary: PathListViewController? {
        splitViewController?.viewController(for: .secondary) as? PathListViewController
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
            layoutConf.trailingSwipeActionsConfigurationProvider = { (indexPath: IndexPath) -> UISwipeActionsConfiguration? in
                let sectionAndRow = (indexPath.section, indexPath.row)
                
                // dont allow the first section or the first item of the first section (/) to be removed
                guard sectionAndRow != (0, 0) && sectionAndRow != (0, 1) else {
                    return nil
                }
                
                let removeAction = UIContextualAction(style: .destructive, title: nil) { [self] _, _, completion in
                    switch dataSource.itemIdentifier(for: indexPath) {
                    case .section(let name): // removing a section
                        UserPreferences.pathGroups.remove(at: indexPath.section)
                        removeSection(name)
                    case .item(_): // removing a row
                        UserPreferences.pathGroups[indexPath.section].paths.remove(at: indexPath.row - 1)
                    default: // should never get here (we only get here if itemIdentifier returns nil)
                        return completion(false)
                    }
                    
                    return completion(true)
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
            case .section(let headerTitle):
                conf = .sidebarHeader()
                conf.text = headerTitle
                cell.accessories = [.outlineDisclosure()]
            case .item(var path):
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
        var snapshot = dataSource.snapshot()
        if snapshot.sectionIdentifiers.isEmpty {
            snapshot.appendSections(pathGroups.map(\.name))
            dataSource.apply(snapshot)
        }
        
        for group in pathGroups {
            var sectionSnapshot = NSDiffableDataSourceSectionSnapshot<Item>()
            let section: Item = .section(group.name)
            sectionSnapshot.append([section])
            sectionSnapshot.expand([section])
            
            let items = Item.fromItems(group.paths.map(Path.init(url:)))
            sectionSnapshot.append(items, to: section)
            dataSource.apply(sectionSnapshot, to: group.name)
        }
    }
    
    func removeSection(_ name: String) {
        var snapshot = dataSource.snapshot()
        snapshot.deleteSections([name])
        dataSource.apply(snapshot)
    }
    
    func goToPath(path: Path) {
        let secondary = subPathsSecondary
        if !path.isDirectory {
            secondary?.goToFile(path: path)
            return
        }
        
        if let currentSubpathsPath = secondary?.currentPath {
            // make sure we're not going to a directory that the secondary column is already showing
            // or is a subpath of
            guard currentSubpathsPath != path else { return }
            
            // this is triggered if, for example, we're in /var/jb/tweaks and we pressed on the button
            // to go to /var or /var/jb
            // then we pop to the view controller rather than creating new ones
            if currentSubpathsPath.path.hasPrefix(path.path) {
                if let vcs = secondary?.navigationController?.viewControllers as? [PathListViewController],
                   let first = vcs.first(where: { $0.currentPath == path }) {
                       secondary?.navigationController?.popToViewController(first, animated: true)
                }
            } else if path.deletingLastPathComponent() != currentSubpathsPath {
                // if we're going to a path that has multiple parents after the current path
                // ie, going to /var/mobile/Media from /var
                // call the traverse function
                secondary?.traverseThroughPath(path)
            } else {
                splitViewController?.setViewController(PathListViewController(path: path), for: .secondary)
            }
            
        } else {
            let vc = PathListViewController(path: .root)
            splitViewController?.setViewController(vc, for: .secondary)
            if path != .root { subPathsSecondary?.traverseThroughPath(path) }
        }
    }
    
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard let item = dataSource.itemIdentifier(for: indexPath) else { return }
        switch item {
        case .section(_): break // shouldn't get here
        case .item(let path):
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
