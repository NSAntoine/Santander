//
//  PathInformationTableView.swift
//  Santander
//
//  Created by Serena on 21/06/2022
//
	

import UIKit

class PathInformationTableView: UITableViewController {
    let path: URL
    
    // show type identifier rather than description
    // ie, com.apple.property-list rather than Property List
    var showTypeIdentifier: Bool = false
    
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
            return self.path.isDirectory ? 3 : 2
        case 1:
            return 2
        case 2:
            if self.path.typeIdentifier != nil || self.path.localizedTypeDescription != nil {
                return 2
            }
            
            return 1
        case 3:
            return self.path.isDirectory ? 3 : 4
        default:
            fatalError("Impossible to be here")
        }
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        // If the user tapped on the "Type", switch between type identifier & type descriptions
        if (indexPath.section, indexPath.row) == (2, 1) {
            showTypeIdentifier.toggle()
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
            conf.text = "Items"
            conf.secondaryText = self.path.contents.count.description
        case (1, 0):
            conf.text = "Creation Date"
            
            conf.secondaryText = (try? self.path.resourceValues(forKeys: [.creationDateKey]).creationDate)?
                .formatted(
                date: .long,
                time: .shortened
            ) ?? "N/A"
            
        case (1, 1):
            conf.text = "Modification Date"
            
            conf.secondaryText = (try? self.path.resourceValues(
                forKeys: [.contentModificationDateKey]
            ))?.contentModificationDate?.formatted(
                date: .long,
                time: .shortened
            ) ?? "N/A"
            
        case (2, 0):
            conf.text = "Type"
            
            let replacementText = self.path.isDirectory ? "Directory" : "File"
            conf.secondaryText = replacementText
        case (2, 1):
            conf.text = "Kind"
            
            let secondaryText: String?
            
            if showTypeIdentifier {
                secondaryText = self.path.typeIdentifier
            } else {
                secondaryText = self.path.localizedTypeDescription
            }
            
            conf.secondaryText = secondaryText
            
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
    
}
