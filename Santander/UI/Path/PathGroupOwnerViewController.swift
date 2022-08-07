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
    
    // all groups / users
    var allData: [String] = []
    
    // allData but filtered by search text
    var filteredData: [String] = [] {
        didSet {
            tableView.reloadData()
        }
    }
    
    /// The data to display in the UI
    var data: [String] {
        return filteredData.isEmpty ? allData : filteredData
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
        DispatchQueue.main.async {
            self.allData = self.type.getAll(forURL: self.fileURL)
            self.tableView.reloadData()
        }
        
        self.title = typeName(capitalizingFirstLetter: true)
        let searchController = UISearchController(searchResultsController: nil)
        searchController.searchBar.delegate = self
        navigationItem.hidesSearchBarWhenScrolling = false
        navigationItem.searchController = searchController
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return data.count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell()
        let item = data[indexPath.row]
        var conf = cell.defaultContentConfiguration()
        conf.text = item
        cell.contentConfiguration = conf
        if type.name == item {
            cell.accessoryType = .checkmark
        }
        return cell
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let item = data[indexPath.row]
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
            tableView.reloadData()
            
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
    }
    
    /// The list of items to display,
    /// either being groups or owners
    enum ItemType: CustomStringConvertible {
        case group(groupName: String), owner(ownerName: String)
        
        /// Returns a string array of either types
        func getAll(forURL url: URL) -> [String] {
            switch self {
            case .owner:
                var arr: [String] = []
                while let pwent = getpwent() {
                    arr.append(String(cString: pwent.pointee.pw_name))
                }
                endpwent()
                
                return arr
            case .group:
                guard let owner = passwd(fileURLOwner: url) else {
                    return []
                }
                
                var groups: gid_t = 0
                var count: Int32 = Int32(sysconf(_SC_NGROUPS_MAX))
                getgrouplist(owner.pw_name, Int32(owner.pw_gid), &groups, &count)
                return convert(length: Int(count), data: &groups, gid_t.self).compactMap { gid in
                    guard let gr = getgrgid(gid)?.pointee.gr_name else {
                        return nil
                    }
                    return String(cString: gr)
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
        
        /// The name of the value associated with the value
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
                try FileManager.default.setAttributes([.ownerAccountName: ownerName], ofItemAtPath: url.path)
            case .group(let groupName):
                try FileManager.default.setAttributes([.groupOwnerAccountName: groupName], ofItemAtPath: url.path)
            }
        }
        
        /// Converts a pointer to an Array
        func convert<T>(length: Int, data: UnsafePointer<T>, _: T.Type) -> [T] {
            let buffer = data.withMemoryRebound(to: T.self, capacity: length) {
                UnsafeBufferPointer(start: $0, count: length)
            }
            
            return Array(buffer)
        }
    }
}

extension PathGroupOwnerViewController: UISearchBarDelegate {
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        filteredData = allData.filter { _data in
            return _data.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    func searchBarCancelButtonClicked(_ searchBar: UISearchBar) {
        filteredData = []
    }
}
