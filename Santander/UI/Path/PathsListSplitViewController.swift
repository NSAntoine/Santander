//
//  PathsListSplitViewController.swift
//  Santander
//
//  Created by Serena on 25/06/2022
//
	

import UIKit

/// Represents the split view to be used on iPads
class PathListsSplitViewController: SubPathsTableViewController {
    var pathGroups = UserPreferences.pathGroups
    
    /// The action for editing the path groups
    lazy var editAction = UIAction { _ in
        self.setEditing(!self.isEditing, animated: true)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.navigationItem.rightBarButtonItem = nil
        self.navigationItem.searchController = nil
        
        NotificationCenter.default.addObserver(forName: .pathGroupsDidChange, object: nil, queue: nil) { _ in
            self.pathGroups = UserPreferences.pathGroups
            self.showPaths()
        }
        setupOrUpdateToolbar()
    }
    
    override func showPaths(animatingDifferences: Bool = true) {
        var snapshot = self.dataSource.snapshot()
        snapshot.deleteAllItems()
        for num in 0..<pathGroups.count {
            snapshot.appendSections([num])
            snapshot.appendItems(SubPathsRowItem.fromPaths(pathGroups[num].paths), toSection: num)
        }
        
        dataSource.apply(snapshot, animatingDifferences: animatingDifferences)
    }
    
    override func hideToolbar() {}
    
    override func setupOrUpdateToolbar() {
        self.toolbarItems = [
            UIBarButtonItem(systemItem: .add, primaryAction: UIAction(withClosure: newGroup)),
            UIBarButtonItem(systemItem: .edit, primaryAction: editAction)
        ]
        
        self.navigationController?.setToolbarHidden(false, animated: false)
    }
    
    override func setRightBarButton() {}
    
    override func goToPath(path: URL, pushingToSplitViewVC: Bool = false) {
        guard path != currentPath else {
            return
        }
        
        super.goToPath(path: path, pushingToSplitViewVC: true)
    }
    
    var collapsedSections: Set<Int> = []
    
    override func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        let group = pathGroups[indexPath.section]
        // Make sure the default group can't be removed
        guard group != .default else {
            return nil
        }
        
        let removeAction = UIContextualAction(style: .destructive, title: nil) { _, _, completion in
            UserPreferences.pathGroups[indexPath.section].paths.remove(at: indexPath.row)
            completion(true)
        }
        
        removeAction.image = .remove
        return UISwipeActionsConfiguration(actions: [removeAction])
    }

    override var contents: [URL] {
        return pathGroups.flatMap(\.paths)
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let item = pathGroups[indexPath.section].paths[indexPath.row]
        goToPath(path: item)
        self.currentPath = pathGroups[indexPath.section].paths[indexPath.row] // Set the current path
        
        popBackIfNeeded(toItem: item)
    }
    
    /// Pops back the secondary vc if a parent path in the list is tapped
    func popBackIfNeeded(toItem item: URL) {
        if let secondary = splitViewController?.viewController(for: .secondary) as? SubPathsTableViewController, secondary.currentPath != item {
            let vcs = (secondary.navigationController?.viewControllers as? [SubPathsTableViewController]) ?? []
            if let vcWithCurrentPath = vcs.first(where: { $0.currentPath == item }) {
                secondary.navigationController?.popToViewController(vcWithCurrentPath, animated: true)
            }
        }
    }
    
    override func setLeftBarSelectionButtonItem() {}
    
    override func setEditing(_ editing: Bool, animated: Bool) {
        super.setEditing(editing, animated: animated)
        self.toolbarItems?[1] = UIBarButtonItem(systemItem: editing ? .done : .edit, primaryAction: editAction)
        self.tableView.reloadData()
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
            
            guard !self.pathGroups.map(\.name).contains(name) else {
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
        
        return sectionHeaderWithButton(
            action: #selector(sectionButtonClicked(_:)),
            sectionTag: section,
            titleText: pathGroups[section].name) { button in
                button.setImage(UIImage(systemName: isEditing ? "trash" : "chevron.down"), for: .normal)
                if self.isEditing {
                    button.tintColor = .systemRed
                }
            }
    }
    
    @objc
    func sectionButtonClicked(_ sender: UIButton) {
        let section = sender.tag
        
        if isEditing {
            // we're deleting the section
            UserPreferences.pathGroups.remove(at: section)
            var snapshot = dataSource.snapshot()
            snapshot.deleteSections([section])
            self.dataSource.apply(snapshot)
            return
        }
        
        let isCollapsing: Bool = !(self.collapsedSections.contains(section))
        let newImageToSet = isCollapsing ? "chevron.forward" : "chevron.down"
        let animationOptions: UIView.AnimationOptions = isCollapsing ? .transitionFlipFromLeft : .transitionFlipFromRight

        UIView.transition(with: sender, duration: 0.3, options: animationOptions) {
            sender.setImage(UIImage(systemName: newImageToSet), for: .normal)
        }

        var snapshot = dataSource.snapshot()
        if isCollapsing {
            // Need to capture the index paths *before inserting* when collapsing
            collapsedSections.insert(section)
            snapshot.deleteItems(snapshot.itemIdentifiers(inSection: section))
        } else {
            collapsedSections.remove(section)
            let itemsToAddBack = SubPathsRowItem.fromPaths(pathGroups[section].paths)
            snapshot.appendItems(itemsToAddBack, toSection: section)
        }
        
        self.dataSource.apply(snapshot)
    }
    
    override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        // we just want the normal height for the first section (which is the nameless section)
        guard section != 0 else {
            return super.tableView(tableView, heightForHeaderInSection: section)
        }
        
        return 40
    }
    
    override func tableView(_ tableView: UITableView, editingStyleForRowAt indexPath: IndexPath) -> UITableViewCell.EditingStyle {
        // we don't want the item in the default section to be deletable
        return indexPath.section == 0 ? .none : .delete
    }
    
    override func tableView(_ tableView: UITableView, shouldIndentWhileEditingRowAt indexPath: IndexPath) -> Bool {
        // don't indent the item in the default section
        return indexPath.section != 0
    }
    
}
