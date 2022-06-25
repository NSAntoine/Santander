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
        guard self.contents.count > 1 else {
            return nil
        }
        
        let removeAction = UIContextualAction(style: .destructive, title: nil) { _, _, completion in
            UserPreferences.sidebarPaths.remove(at: indexPath.row)
            self.unfilteredContents = UserPreferences.sidebarPaths.map { URL(fileURLWithPath: $0) }
            self.tableView.deleteRows(at: [indexPath], with: .fade)
            completion(true)
        }
        
        return UISwipeActionsConfiguration(actions: [removeAction])
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        
        super.tableView(tableView, didSelectRowAt: indexPath)
        self.currentPath = contents[indexPath.row] // Set the current path
    }
    
}
