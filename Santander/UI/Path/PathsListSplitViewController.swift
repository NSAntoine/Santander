//
//  PathsListSplitViewController.swift
//  Santander
//
//  Created by Serena on 25/06/2022
//
	

import UIKit

/// Represents the split view to be used
class PathListsSplitViewController: PathContentsTableViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Select the first item by default
        tableView(self.tableView, didSelectRowAt: [0, 0])
        self.navigationItem.rightBarButtonItem = nil
        self.navigationItem.searchController = nil
        self.toolbarItems = [UIBarButtonItem(title: "New group..", style: .plain, target: self, action: #selector(newGroup))]
        NotificationCenter.default.addObserver(forName: .pathGroupsDidChange, object: nil, queue: nil) { _ in
            self.tableView.reloadData()
        }
        self.navigationController?.setToolbarHidden(false, animated: false)
    }
    
    override func goToPath(path: URL) {
        guard path != currentPath else {
            return
        }
        
        if path.isDirectory || self.isSearching {
            // Make sure we're opening a directory,
            // or the parent directory of the file selected
            let dirToOpen = path.isDirectory ? path : path.deletingLastPathComponent()
            self.splitViewController?.setViewController(
                UINavigationController(rootViewController: PathContentsTableViewController(path: dirToOpen)), for: .secondary)
        } else {
            self.goToFile(path: path)
        }
    }
    
    override func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        let pathGroups = UserPreferences.pathGroups[indexPath.section]
        guard !(pathGroups.paths[indexPath.row] == .root && pathGroups.name == "Defaults") else {
            return nil
        }
        
        let removeAction = UIContextualAction(style: .destructive, title: nil) { _, _, completion in
            UserPreferences.pathGroups[indexPath.section].paths.remove(at: indexPath.row)
            
            if UserPreferences.pathGroups[safe: indexPath.section]?.paths.isEmpty ?? false {
                // if the group is now empty, completely remove it
                UserPreferences.pathGroups.remove(at: indexPath.section)
            }
            
            completion(true)
        }
        
        return UISwipeActionsConfiguration(actions: [removeAction])
    }

    override var contents: [URL] {
        return UserPreferences.pathGroups.flatMap(\.paths)
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let item = UserPreferences.pathGroups[indexPath.section].paths[indexPath.row]
        goToPath(path: item)
        self.currentPath = UserPreferences.pathGroups[indexPath.section].paths[indexPath.row] // Set the current path
    }
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return UserPreferences.pathGroups.count
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return UserPreferences.pathGroups[section].paths.count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        cellRow(forURL: UserPreferences.pathGroups[indexPath.section].paths[indexPath.row], displayFullPathAsSubtitle: true)
    }
    
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        UserPreferences.pathGroups[section].name
    }
    
    @objc func newGroup() {
        let alert = UIAlertController(title: "New group", message: "Enter the name of the group", preferredStyle: .alert)
        alert.addTextField { textField in
            textField.placeholder = "name.."
        }
        
        let addAction = UIAlertAction(title: "Add", style: .default) { _ in
            guard let name = alert.textFields?.first?.text, !name.isEmpty else {
                alert.dismiss(animated: true)
                self.errorAlert("Name must be inputted", title: "Invalid name")
                return
            }
            
            guard !UserPreferences.pathGroups.map(\.name).contains(name) else {
                alert.dismiss(animated: true)
                self.errorAlert("\"\(name)\" Already exists", title: "Item already exists")
                return
            }
            
            UserPreferences.pathGroups.append(.init(name: name, paths: []))
            self.tableView.reloadData()
        }
        
        alert.addAction(.init(title: "Cancel", style: .cancel))
        alert.addAction(addAction)
        self.present(alert, animated: true)
    }
}
