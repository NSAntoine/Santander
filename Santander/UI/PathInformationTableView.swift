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
        return 3
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch section {
        case 0:
            var num = 3
            
            // If the type, ie 'Property List', is available
            // add a row for it
            if self.path.localizedTypeDescription != nil {
                num += 1
            }
            
            if self.path.isDirectory {
                num += 1
            }
            
            return num
        case 1:
            return 3
        case 2:
            return self.path.isDirectory ? 3 : 4
        default:
            fatalError("Impossible to be here")
        }
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if (indexPath.section, indexPath.row) == (0, 2) {
            showByteCount.toggle()
            tableView.reloadRows(at: [indexPath], with: .automatic)
        }
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: .value1, reuseIdentifier: nil)
        var conf = cell.defaultContentConfiguration()
        switch (indexPath.section, indexPath.row) {
        case (0, 0):
            conf.text = "Name"
            conf.secondaryText = self.path.lastPathComponent
        case (0, 1):
            conf.text = "Path"
            conf.secondaryText = self.path.path
        case (0, 2):
            conf.text = "Size"
            if let size = self.path.size {
                conf.secondaryText = ByteCountFormatStyle(style: .file, allowedUnits: .all, spellsOutZero: false, includesActualByteCount: showByteCount).format(Int64(size))
            } else {
                conf.secondaryText = "N/A"
            }
        case (0, 3):
            conf.text = self.path.isDirectory ? "Items" : "Type"
            conf.secondaryText = self.path.isDirectory ? self.path.contents.count.description : self.path.localizedTypeDescription
        case (0, 4): // this is only encountered when we have a directory with a type description
            conf.text = "Type"
            conf.secondaryText = self.path.localizedTypeDescription
        case (1, 0):
            conf.text = "Created"
            
            conf.secondaryText = self.path.creationDate?
                .formatted(
                date: .long,
                time: .shortened
            ) ?? "N/A"
            
        case (1, 1):
            conf.text = "Last modified"
            
            conf.secondaryText = path.lastModifiedDate?
                .formatted(
                date: .long,
                time: .shortened
            ) ?? "N/A"
            
        case (1, 2):
            conf.text = "Last accessed"
            
            conf.secondaryText = path.lastAccessedDate?
                .formatted(
                date: .long,
                time: .shortened
            ) ?? "N/A"
            
        case (2, 0):
            conf.text = "Deletable"
            conf.secondaryText = FileManager.default.isDeletableFile(atPath: self.path.path) ? "Yes" : "No"
        case (2, 1):
            conf.text = "Readable"
            conf.secondaryText = FileManager.default.isReadableFile(atPath: self.path.path) ? "Yes" : "No"
        case (2, 2):
            conf.text = "Writable"
            conf.secondaryText = FileManager.default.isWritableFile(atPath: self.path.path) ? "Yes" : "No"
        case (2, 3):
            conf.text = "Executable"
            conf.secondaryText = FileManager.default.isExecutableFile(atPath: self.path.path) ? "Yes" : "No"
        default: break
        }
        
        cell.contentConfiguration = conf
        return cell
    }
    
}
