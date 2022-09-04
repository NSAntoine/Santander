//
//  PathPermissionsViewController.swift
//  Santander
//
//  Created by Serena on 05/08/2022.
//

import UIKit

class PathPermissionsViewController: UITableViewController {
    var permissions: PathPermissions
    
    // in case setting the permissions fail, we need this clone to revert the original
    // back to this initial clone which doesn't get modified
    let _permissionsClone: PathPermissions
    
    lazy var editAction = UIAction {
        self.setEditing(!self.isEditing, animated: true)
    }
    
    init(style: UITableView.Style = .insetGrouped, permissions: PathPermissions) {
        self.permissions = permissions
        self._permissionsClone = permissions
        
        super.init(style: style)
        self.title = "Permissions"
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        navigationItem.rightBarButtonItem = UIBarButtonItem(systemItem: .edit, primaryAction: editAction)
        tableView.allowsSelectionDuringEditing = true
    }
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 3
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch section {
        case 0, 1: return 4
        case 2: return 3
        default: fatalError("How did we get here?!")
        }
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        return cell(atIndexPath: indexPath)
    }
    
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch section {
        case 0: return "Owner"
        case 1: return "Group"
        case 2: return "Other users"
        default: return nil
        }
    }
    
    func cell(
        atIndexPath indexPath: IndexPath
    ) -> UITableViewCell {
        let cell = UITableViewCell(style: .value1, reuseIdentifier: nil)
        let permSet: Permission
        var firstRowText: String? = nil
        var firstRowSecondaryText: String? = nil
        
        switch indexPath.section {
        case 0:
            permSet = self.permissions.ownerPermissions
            firstRowText = "Owner"
            firstRowSecondaryText = self.permissions.ownerName
        case 1:
            permSet = self.permissions.groupPermissions
            firstRowText = "Group"
            firstRowSecondaryText = self.permissions.groupOwnerName
        case 2:
            permSet = self.permissions.otherUsersPermissions
        default:
            fatalError()
        }
        
        var conf = cell.defaultContentConfiguration()
        defer {
            cell.contentConfiguration = conf
        }
        
        if indexPath.row == correctRow(0, indexPath: indexPath) {
            conf.text = firstRowText
            conf.secondaryText = firstRowSecondaryText ?? "N/A"
            cell.accessoryType = .disclosureIndicator
            cell.editingAccessoryType = .disclosureIndicator
            cell.isUserInteractionEnabled = tableView(self.tableView, shouldHighlightRowAt: indexPath)
            return cell
        }

        let toCheck = permissionAtRow(atIndexPath: indexPath)
        switch indexPath.row {
        case correctRow(1, indexPath: indexPath):
            conf.text = "Read"
            conf.secondaryText = permSet.contains(toCheck) ? "Yes" : "No"
        case correctRow(2, indexPath: indexPath):
            conf.text = "Write"
            conf.secondaryText = permSet.contains(toCheck) ? "Yes" : "No"
        case correctRow(3, indexPath: indexPath):
            conf.text = "Execute"
            conf.secondaryText = permSet.contains(toCheck) ? "Yes" : "No"
        default:
            fatalError("Shouldn't have gotten here! row received: \(indexPath.row)")
        }
        
        if self.isEditing {
            conf.secondaryText = nil
            if permSet.contains(toCheck) {
                cell.editingAccessoryType = .checkmark
            }
        }
        
        return cell
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if indexPath.row == correctRow(0, indexPath: indexPath) {
            let name = indexPath.section == 0 ? permissions.ownerName : permissions.groupOwnerName
            guard let name = name else {
                return // should NEVER be here
            }
            
            let type: PathGroupOwnerViewController.ItemType
            switch indexPath.section {
            case 0:
                type = .owner(ownerName: name)
            case 1:
                type = .group(groupName: name)
            default:
                fatalError()
            }
            self.navigationController?.pushViewController(PathGroupOwnerViewController(style: .insetGrouped, type: type, sourceVC: self, fileURL: permissions.fileURL), animated: true)
            return
        }
        
        guard self.isEditing else {
            return
        }
        
        let perm = permissionAtRow(atIndexPath: indexPath)
        switch indexPath.section {
        case 0:
            removeOrAddPermission(fromOptionSet: &permissions.ownerPermissions, forPermission: perm)
        case 1:
            removeOrAddPermission(fromOptionSet: &permissions.groupPermissions, forPermission: perm)
        case 2:
            removeOrAddPermission(fromOptionSet: &permissions.otherUsersPermissions, forPermission: perm)
        default:
            break
        }
        tableView.reloadRows(at: [indexPath], with: .fade)
    }
    
    override func tableView(_ tableView: UITableView, shouldHighlightRowAt indexPath: IndexPath) -> Bool {
        if indexPath.row == correctRow(0, indexPath: indexPath) {
            switch indexPath.section {
            case 0:
                return permissions.ownerName != nil
            case 1:
                return permissions.groupOwnerName != nil
            default:
                fatalError()
            }
        }
        
        return self.isEditing
    }
    
    func permissionAtRow(atIndexPath indexPath: IndexPath) -> Permission {
        switch indexPath.row {
        case correctRow(1, indexPath: indexPath):
            return .read
        case correctRow(2, indexPath: indexPath):
            return .write
        case correctRow(3, indexPath: indexPath):
            return .execute
        default:
            fatalError()
        }
    }
    
    /// Due to the fact that the first row in the second section
    /// is different than the others, this function must be used to determine
    /// the appropriate indexPath
    func correctRow(_ num: Int, indexPath: IndexPath) -> Int {
        return indexPath.section == 2 ? num - 1 : num
    }
    
    override func setEditing(_ editing: Bool, animated: Bool) {
        super.setEditing(editing, animated: animated)
        
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            systemItem: editing ? .done : .edit,
            primaryAction: editAction
        )
        
        // applying the permissions
        if !editing, permissions != _permissionsClone {
            do {
                try permissions.apply()
            } catch {
                self.errorAlert(error, title: "Unable to change permissions of \"\(permissions.fileURL.lastPathComponent)\"")
                self.permissions = _permissionsClone
            }
        }
        
        self.tableView.reloadData()
    }
    
    override func tableView(_ tableView: UITableView, shouldIndentWhileEditingRowAt indexPath: IndexPath) -> Bool {
        return false
    }
    
    override func tableView(_ tableView: UITableView, editingStyleForRowAt indexPath: IndexPath) -> UITableViewCell.EditingStyle {
        return .none
    }
    
    /// Removes or adds the permission to the OptionSet
    func removeOrAddPermission(fromOptionSet set: inout Permission, forPermission perm: Permission) {
        if set.contains(perm) {
            set.remove(perm)
        } else {
            set.insert(perm)
        }
    }
    
}
