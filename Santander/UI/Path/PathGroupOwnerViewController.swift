//
//  PathGroupOwnerViewController.swift
//  Santander
//
//  Created by Serena on 07/08/2022.
//

import UIKit

/// A ViewController allowing you to set either the owner or the group of a path
class PathGroupOwnerViewController: UITableViewController {
    var type: ItemType
    var sourceVC: PathPermissionsViewController?
    let fileURL: URL
    
    enum Section {
        case main
    }
    
    var allData: [ItemType] = []
    
    typealias DataSource = UITableViewDiffableDataSource<Section, ItemType>
    lazy var dataSource = DataSource(tableView: tableView) { [self] tableView, indexPath, itemIdentifier in
        let item = itemIdentifier.name
        
        let cell = UITableViewCell()
        var conf = cell.defaultContentConfiguration()
        
        conf.text = item
        cell.contentConfiguration = conf
        if type.name == item {
            cell.accessoryType = .checkmark
        }
        return cell
    }
    
    func typeName(capitalizingFirstLetter: Bool) -> String {
        switch type {
        case .group(_):
            return capitalizingFirstLetter ? "Group" : "group"
        case .owner(_):
            return capitalizingFirstLetter ? "Owner" : "owner"
        }
    }
    
    init(style: UITableView.Style, type: ItemType, sourceVC: PathPermissionsViewController, fileURL: URL) {
        self.type = type
        self.sourceVC = sourceVC
        self.fileURL = fileURL
        
        super.init(style: style)
    }
    
    override func viewDidLoad() {
        self.title = typeName(capitalizingFirstLetter: true)
        let searchController = UISearchController(searchResultsController: nil)
        searchController.searchBar.delegate = self
        navigationItem.hidesSearchBarWhenScrolling = false
        navigationItem.searchController = searchController
        
        // load data
        Task { [self] in
            do {
                allData = try type.getAll(forURL: fileURL)
                applyItems(allData, animatingDifference: true)
            } catch {
                showError(error)
                searchController.searchBar.isUserInteractionEnabled = false
            }
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let item = dataSource.itemIdentifier(for: indexPath)!.name
        let oldType = type
        var newType: ItemType
        switch type {
        case .owner(_):
            newType = .owner(ownerName: item)
        case .group(_):
            newType = .group(groupName: item)
        }
        
        do {
            try newType.set(forURL: fileURL)
            self.type = newType
            
            // Update the parent permissions vc
            switch newType {
            case .owner(let ownerName):
                sourceVC?.permissions.ownerName = ownerName
            case .group(let groupName):
                sourceVC?.permissions.groupOwnerName = groupName
            }
            sourceVC?.tableView.reloadData()
        } catch {
            self.errorAlert(error, title: "Unable to change \(typeName(capitalizingFirstLetter: false)) of \(fileURL.lastPathComponent)")
        }
        
        tableView.deselectRow(at: indexPath, animated: true)
        var snapshot = dataSource.snapshot()
        
        var itemsToReload = [type]
        // if the old item is visible, reload it
        if let oldItemIndexPath = dataSource.indexPath(for: oldType), tableView.bounds.contains(tableView.rectForRow(at: oldItemIndexPath)) {
            itemsToReload.append(oldType)
        }
        
        snapshot.reloadItems(itemsToReload)
        dataSource.apply(snapshot, animatingDifferences: false)
    }
    
    func showError(_ error: Error) {
        let errorLabel = UILabel()
        errorLabel.text = error.localizedDescription
        errorLabel.textAlignment = .center
        errorLabel.numberOfLines = 0
        errorLabel.lineBreakMode = .byWordWrapping
        errorLabel.textColor = .systemGray
        
        errorLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(errorLabel)
        let guide = view.layoutMarginsGuide
        NSLayoutConstraint.activate([
            errorLabel.widthAnchor.constraint(equalTo: guide.widthAnchor),
            errorLabel.centerXAnchor.constraint(equalTo: guide.centerXAnchor),
            errorLabel.centerYAnchor.constraint(equalTo: guide.centerYAnchor),
        ])
    }
    
    /// The list of items to display,
    /// either being groups or owners
    enum ItemType: Hashable, CustomStringConvertible {
        case group(groupName: String), owner(ownerName: String)
        
        /// Returns a string array of either types
        func getAll(forURL url: URL) throws -> [ItemType] {
            switch self {
            case .owner:
                var arr: [String] = []
                while let pwent = getpwent() {
                    arr.append(String(cString: pwent.pointee.pw_name))
                }
                endpwent()
                
                return arr.map(ItemType.owner(ownerName:))
            case .group:
                guard let owner = passwd(fileURLOwner: url) else {
                    throw Errors.unableToGetGroups(description: "Failed to fetch groups, cause: owner is unknown")
                }
                
                var groups: Int32 = 0
                var count: Int32 = Int32(sysconf(_SC_NGROUPS_MAX))
                getgrouplist(owner.pw_name, Int32(owner.pw_gid), &groups, &count)
                let converted = convert(length: Int(count), data: &groups).compactMap { gid -> String? in
                    guard let gr = getgrgid(gid_t(gid))?.pointee.gr_name else {
                        return nil
                    }
                    
                    return String(cString: gr)
                }
                
                return converted.map(ItemType.group(groupName:))
            }
        }
        
        enum Errors: Error, LocalizedError {
            case unableToGetGroups(description: String)
            
            var errorDescription: String? {
                switch self {
                case .unableToGetGroups(let description):
                    return description
                }
            }
        }
        
        var description: String {
            switch self {
            case .owner(let ownerName):
                return "Owner (owner name: \(ownerName))"
            case .group(let groupName):
                return "Group (group name: \(groupName))"
            }
        }
        
        var name: String {
            switch self {
            case .owner(let ownerName):
                return ownerName
            case .group(let groupName):
                return groupName
            }
        }
        
        /// Sets the type with the name
        /// for the given path
        func set(forURL url: URL) throws {
            switch self {
            case .owner(let ownerName):
                try FSOperation.perform(.setOwner(url: url, newOwner: ownerName), rootHelperConf: RootConf.shared)
            case .group(let groupName):
                try FSOperation.perform(.setGroup(url: url, newGroup: groupName), rootHelperConf: RootConf.shared)
            }
        }
        
        /// Converts a pointer to an Array
        private func convert<T>(length: Int, data: UnsafePointer<T>) -> [T] {
            let buffer = data.withMemoryRebound(to: T.self, capacity: length) {
                UnsafeBufferPointer(start: $0, count: length)
            }
            
            return Array(buffer)
        }
    }
    
    func applyItems(_ items: [ItemType], animatingDifference: Bool = false) {
        var snapshot = NSDiffableDataSourceSnapshot<Section, ItemType>()
        snapshot.appendSections([.main])
        snapshot.appendItems(items, toSection: .main)
        dataSource.apply(snapshot, animatingDifferences: animatingDifference)
    }
}

extension PathGroupOwnerViewController: UISearchBarDelegate {
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        if searchText.isEmpty {
            applyItems(allData, animatingDifference: true)
            return
        }
        
        let filtered = allData.filter { item in
            item.name.localizedCaseInsensitiveContains(searchText)
        }
        
        applyItems(filtered, animatingDifference: true)
    }
    
    func searchBarCancelButtonClicked(_ searchBar: UISearchBar) {
        applyItems(allData, animatingDifference: true)
    }
}
