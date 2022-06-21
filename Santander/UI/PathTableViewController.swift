//
//  PathTableViewController.swift
//  Santander
//
//  Created by Serena on 21/06/2022
//
	

import UIKit

class PathContentsTableViewController: UITableViewController {
    let path: URL
    
    var sortedContents: [URL] {
        path.contents.sorted { firstURL, secondURL in
            firstURL.lastPathComponent < secondURL.lastPathComponent
        }
    }
    
    init(style: UITableView.Style = .plain, path: URL) {
        self.path = path
        
        super.init(style: style)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.title = path.lastPathComponent
        
        if self.path.contents.isEmpty && self.path.isDirectory {
            let label = UILabel()
            label.text = "No items in \(path.lastPathComponent) directory"
            label.font = .systemFont(ofSize: 20, weight: .medium)
            label.textColor = .systemGray
            
            self.view.addSubview(label)
            label.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                label.centerXAnchor.constraint(equalTo: self.view.centerXAnchor),
                label.centerYAnchor.constraint(equalTo: self.view.centerYAnchor)
            ])
        }
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.path.contents.count
    }
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    override func tableView(_ tableView: UITableView, accessoryButtonTappedForRowWith indexPath: IndexPath) {
        let navController = UINavigationController(
            rootViewController: PathInformationTableView(style: .insetGrouped, path: sortedContents[indexPath.row])
        )
        
        navController.modalPresentationStyle = .pageSheet
        
        if let sheetController = navController.sheetPresentationController {
            sheetController.detents = [.medium(), .large()]
        }
        
        self.present(navController, animated: true)
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        self.navigationController?.pushViewController(
            PathContentsTableViewController(path: sortedContents[indexPath.row]),
            animated: true
        )
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell()
        var cellConf = cell.defaultContentConfiguration()
        
        let fsItem = sortedContents[indexPath.row]
        cellConf.text = fsItem.lastPathComponent
        
        // if the item starts is a dotfile / dotdirectory
        // ie, .conf or .zshrc,
        // display it as gray
        if fsItem.lastPathComponent.hasPrefix(".") {
            cellConf.textProperties.color = .gray
        }
        
        if fsItem.isDirectory {
            cellConf.image = UIImage(systemName: "folder.fill")
        } else {
            // TODO: we should display the icon for the file with https://indiestack.com/2018/05/icon-for-file-with-uikit/
            cellConf.image = UIImage(systemName: "doc.fill")
        }
        
        // If the item is a file, show just the "i" icon,
        // otherwise show the icon & a disclosure button
        cell.accessoryType = .detailDisclosureButton 
        cell.contentConfiguration = cellConf
        return cell
    }
}
