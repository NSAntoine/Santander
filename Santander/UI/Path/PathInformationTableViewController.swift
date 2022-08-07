//
//  PathInformationTableViewController.swift
//  Santander
//
//  Created by Serena on 21/06/2022
//
	

import UIKit

/// A Table View Controller displaying information for a given path
class PathInformationTableViewController: UITableViewController {
    let path: URL
    let metadata: PathMetadata
    
    var showByteCount: Bool = false
    var showDisplayName: Bool = false
    var showRealPath: Bool = false
    
    init(style: UITableView.Style, path: URL) {
        self.path = path
        self.metadata = PathMetadata(fileURL: path)
        
        super.init(style: style)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.title = self.path.lastPathComponent
    }
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 4
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch section {
        case 0:
            return self.path.isDirectory ? 4 : 3
        case 1:
            return metadata.contentType?.preferredMIMEType != nil ? 2 : 1
        case 2:
            return 4
        case 3:
            return 1
        default:
            fatalError("Impossible to be here")
        }
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        switch (indexPath.section, indexPath.row) {
        case (0, 0):
            showDisplayName.toggle()
        case (0, 1):
            showRealPath.toggle()
        case (0, 2):
            showByteCount.toggle()
        case (3, 0):
            guard let permissions = metadata.permissions else {
                return
            }
            
            self.navigationController?.pushViewController(PathPermissionsViewController(permissions: permissions), animated: true)
        default:
            return
        }
        
        tableView.reloadRows(at: [indexPath], with: .automatic)
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: .value1, reuseIdentifier: nil)
        var conf = cell.defaultContentConfiguration()
        switch (indexPath.section, indexPath.row) {
        case (0, 0):
            conf.text = showDisplayName ? "Display name" : "Name"
            conf.secondaryText = showDisplayName ? self.path.displayName : self.path.lastPathComponent
        case (0, 1):
            conf.text = showRealPath ? "Real Path" : "Path"
            let pathString: String = showRealPath ? (self.path.realPath ?? "N/A") : self.path.path
            if pathString == "N/A" {
                conf.secondaryText = "N/A"
            } else {
                conf.secondaryText = URL(fileURLWithPath: pathString).path
            }
            
        case (0, 2):
            conf.text = "Size"
            if let size = self.path.size {
                let formatter = ByteCountFormatter()
                formatter.countStyle = .file
                formatter.allowedUnits = .useAll
                formatter.includesActualByteCount = showByteCount
                conf.secondaryText = formatter.string(fromByteCount: Int64(size))
            } else {
                conf.secondaryText = "N/A"
            }
        case (0, 3):
            conf.text = "Items"
            conf.secondaryText = self.path.contents.count.description
        case (1, 0):
            conf.text = "Type"
            conf.secondaryText = metadata.contentType?.localizedDescription?.localizedCapitalized ?? "N/A"
        case (1, 1):
            conf.text = "MIME Type"
            conf.secondaryText = metadata.contentType?.preferredMIMEType ?? "N/A"
        case (2, 0):
            conf.text = "Created"
            conf.secondaryText = metadata.creationDate?.listFormatted() ?? "N/A"
        case (2, 1):
            conf.text = "Added"
            conf.secondaryText = metadata.addedToDirectoryDate?.listFormatted() ?? "N/A"
        case (2, 2):
            conf.text = "Modified"
            conf.secondaryText = metadata.lastModifiedDate?.listFormatted() ?? "N/A"
        case (2, 3):
            conf.text = "Accessed"
            conf.secondaryText = metadata.lastAccessedDate?.listFormatted() ?? "N/A"
        case (3, 0):
            conf.text = "Permissions"
            cell.accessoryType = .disclosureIndicator
            cell.isUserInteractionEnabled = metadata.permissions != nil
        default: break
        }
        
        cell.contentConfiguration = conf
        return cell
    }
    
    override func tableView(_ tableView: UITableView, shouldHighlightRowAt indexPath: IndexPath) -> Bool {
        switch (indexPath.section, indexPath.row) {
        case (0, 0):
            // Only allow display name to be shown if it's different from the lastPathComponent
            return path.displayName != path.lastPathComponent
        case (0, 1):
            return (try? FileManager.default.destinationOfSymbolicLink(atPath: self.path.path)) != nil
        case (0, 2):
            return self.path.size != nil
        case (3, 0):
            return metadata.permissions != nil
        default:
            return false
        }
    }
    
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return headerTitle(forSection: section)
    }
    
    func headerTitle(forSection section: Int) -> String {
        switch section {
        case 0: return "General"
        case 1: return "Type"
        case 2: return "Date Metadata"
        case 3: return "Permissions"
        default: fatalError("\(#function): Unknown Section num \(section)")
        }
    }
}
