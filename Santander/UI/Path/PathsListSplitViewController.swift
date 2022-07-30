//
//  PathsListSplitViewController.swift
//  Santander
//
//  Created by Serena on 25/06/2022
//
	

import UIKit

/// Represents the split view to be used on iPads
class PathListsSplitViewController: SubPathsTableViewController {
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
    
    override func goToPath(path: URL, pushingToSplitViewVC: Bool = false) {
        guard path != currentPath else {
            return
        }
        
        super.goToPath(path: path, pushingToSplitViewVC: true)
    }
    
    var collapsedSections: Set<Int> = []
    
    override func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        let group = UserPreferences.pathGroups[indexPath.section]
        // Make sure the default group can't be removed
        guard group != .default else {
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
        
        removeAction.image = UIImage.remove
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
        if collapsedSections.contains(section) {
            return 0
        }
        
        return UserPreferences.pathGroups[section].paths.count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        cellRow(forURL: UserPreferences.pathGroups[indexPath.section].paths[indexPath.row], displayFullPathAsSubtitle: true)
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
            
            UserPreferences.pathGroups.append(PathGroup(name: name, paths: []))
        }
        
        alert.addAction(.init(title: "Cancel", style: .cancel))
        alert.addAction(addAction)
        self.present(alert, animated: true)
    }
    
    override func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        // if we're in the first section,
        // which has no name, then don't return a header view
        guard section != 0 else {
            return nil
        }
        
        return titleWithChevronView(
            action: #selector(chevronButtonClicked(_:)),
            sectionTag: section,
            titleText: UserPreferences.pathGroups[section].name)
    }
    
    @objc
    func chevronButtonClicked(_ sender: UIButton) {
        let section = sender.tag
        let isCollapsing: Bool = !(self.collapsedSections.contains(section))
        let newImageToSet = isCollapsing ? "chevron.forward" : "chevron.down"
        let animationOptions: UIView.AnimationOptions = isCollapsing ? .transitionFlipFromLeft : .transitionFlipFromRight

        UIView.transition(with: sender, duration: 0.3, options: animationOptions) {
            sender.setImage(UIImage(systemName: newImageToSet), for: .normal)
        }

        if isCollapsing {
            // Need to capture the index paths *before inserting* when collapsing
            let indexPaths: [IndexPath] = self.indexPaths(forSection: section)
            collapsedSections.insert(section)
            tableView.deleteRows(at: indexPaths, with: .fade)
        } else {
            collapsedSections.remove(section)
            tableView.insertRows(at: self.indexPaths(forSection: section), with: .fade)
        }
    }
    
    override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        // we just want the normal height for the first section (which is the nameless section)
        guard section != 0 else {
            return super.tableView(tableView, heightForHeaderInSection: section)
        }
        
        return 40
    }
}
