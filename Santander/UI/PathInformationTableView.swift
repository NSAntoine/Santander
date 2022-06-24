//
//  PathInformationTableView.swift
//  Santander
//
//  Created by Serena on 21/06/2022
//
	

import UIKit

class PathInformationTableView: UITableViewController {
    let path: URL
    
    var showByteCount: Bool = false
    var showDisplayName: Bool = false
    var showRealPath: Bool = false
    
    init(style: UITableView.Style, path: URL) {
        self.path = path
        
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
            return 1
        case 2:
            return 3
        case 3:
            return self.path.isDirectory ? 3 : 4
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
            conf.text = showDisplayName ? "Display Name" : "Name"
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
                conf.secondaryText = ByteCountFormatStyle(style: .file, allowedUnits: .all, spellsOutZero: false, includesActualByteCount: showByteCount).format(Int64(size))
            } else {
                conf.secondaryText = "N/A"
            }
        case (0, 3):
            conf.text = "Items"
            conf.secondaryText = self.path.contents.count.description
        case (1, 0):
            conf.text = "Type"
            conf.secondaryText = self.path.contentType?.localizedDescription?.localizedCapitalized ?? "N/A"
        case (2, 0):
            conf.text = "Created"
            
            conf.secondaryText = self.path.creationDate?
                .formatted(
                date: .long,
                time: .shortened
            ) ?? "N/A"
            
        case (2, 1):
            conf.text = "Last modified"
            
            conf.secondaryText = path.lastModifiedDate?
                .formatted(
                date: .long,
                time: .shortened
            ) ?? "N/A"
            
        case (2, 2):
            conf.text = "Last accessed"
            
            conf.secondaryText = path.lastAccessedDate?
                .formatted(
                date: .long,
                time: .shortened
            ) ?? "N/A"
            
        case (3, 0):
            conf.text = "Deletable"
            conf.secondaryText = FileManager.default.isDeletableFile(atPath: self.path.path) ? "Yes" : "No"
        case (3, 1):
            conf.text = "Readable"
            conf.secondaryText = FileManager.default.isReadableFile(atPath: self.path.path) ? "Yes" : "No"
        case (3, 2):
            conf.text = "Writable"
            conf.secondaryText = FileManager.default.isWritableFile(atPath: self.path.path) ? "Yes" : "No"
        case (3, 3):
            conf.text = "Executable"
            conf.secondaryText = FileManager.default.isExecutableFile(atPath: self.path.path) ? "Yes" : "No"
        default: break
        }
        
        cell.contentConfiguration = conf
        return cell
    }
    
    override func tableView(_ tableView: UITableView, shouldHighlightRowAt indexPath: IndexPath) -> Bool {
        switch (indexPath.section, indexPath.row) {
        case (0, 0):
            return true
        case (0, 1):
            return (try? FileManager.default.destinationOfSymbolicLink(atPath: self.path.path)) != nil
        case (0, 2):
            return self.path.size != nil
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
