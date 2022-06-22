//
//  PathTableViewController.swift
//  Santander
//
//  Created by Serena on 21/06/2022
//
	

import UIKit

/// Represents the subpaths under a Directory
class PathContentsTableViewController: UITableViewController {
    
    /// The contents of the path
    var contents: [URL]
    
    /// The path name to be used as the ViewController's title
    let pathName: String
    
    var sortWay: SortingWays = .alphabetically
    
    /// Initialize with a given path URL
    init(style: UITableView.Style = .plain, path: URL) {
        self.contents = path.contents.sorted { firstURL, secondURL in
            firstURL.lastPathComponent < secondURL.lastPathComponent
        }
        
        self.pathName = path.lastPathComponent
        super.init(style: style)
    }
    
    /// Initialize with the given specified URLs
    init(style: UITableView.Style = .plain, contents: [URL], title: String) {
        self.contents = contents
        self.pathName = title
        
        super.init(style: style)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.title = self.pathName
        
        let sortAction = UIAction(title: "Sort by..") { _ in
            self.presentSortingWays()
        }
        
        self.navigationItem.rightBarButtonItem = UIBarButtonItem(
            image: .init(systemName: "ellipsis.circle.fill"),
            menu: .init(children: [sortAction])
        )
        
        self.navigationController?.navigationBar.prefersLargeTitles = /*UserPreferences.useLargeNavigationTitles*/ true
        
        if self.contents.isEmpty {
            let label = UILabel()
            label.text = "No items found."
            label.font = .systemFont(ofSize: 20, weight: .medium)
            label.textColor = .systemGray
            label.textAlignment = .center
            
            self.view.addSubview(label)
            label.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                label.centerXAnchor.constraint(equalTo: self.view.centerXAnchor),
                label.centerYAnchor.constraint(equalTo: self.view.centerYAnchor)
            ])
        }
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.contents.count
    }
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    override func tableView(_ tableView: UITableView, accessoryButtonTappedForRowWith indexPath: IndexPath) {
        let navController = UINavigationController(
            rootViewController: PathInformationTableView(style: .insetGrouped, path: contents[indexPath.row])
        )
        
        navController.modalPresentationStyle = .pageSheet
        
        if let sheetController = navController.sheetPresentationController {
            sheetController.detents = [.medium(), .large()]
        }
        
        self.present(navController, animated: true)
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        self.navigationController?.pushViewController(
            PathContentsTableViewController(path: contents[indexPath.row]),
            animated: true
        )
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell()
        var cellConf = cell.defaultContentConfiguration()
        
        let fsItem = contents[indexPath.row]
        cellConf.text = fsItem.lastPathComponent
        
        // if the item starts is a dotfile / dotdirectory
        // ie, .conf or .zshrc,
        // display it as gray
        if fsItem.lastPathComponent.first == "." {
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
    
    func presentSortingWays() {
        let actions = SortingWays.allCases.map { type in
            UIAlertAction(title: type.description, style: .default) { _ in
                self.sortContents(with: type)
        }}
        
        let alert = UIAlertController(title: "Sort", message: nil, preferredStyle: .actionSheet)
        for action in actions {
            alert.addAction(action)
        }
        
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel) { _ in }
        alert.addAction(cancelAction)
        
        self.present(alert, animated: true)
    }
    
    func sortContents(with filter: SortingWays) {
        switch filter {
        case .alphabetically:
            self.contents = self.contents.sorted { firstURL, secondURL in
                firstURL.lastPathComponent < secondURL.lastPathComponent
            }
        case .dateCreated:
            self.contents = self.contents.sorted { firstURL, secondURL in
                guard let firstDate = firstURL.creationDate, let secondDate = secondURL.creationDate else {
                    return false
                }
                
                return firstDate > secondDate
            }
        case .dateModified:
            self.contents = self.contents.sorted { firstURL, secondURL in
                guard let firstDate = firstURL.lastModifiedDate, let secondDate = secondURL.lastModifiedDate else {
                    return false
                }
                
                return firstDate > secondDate
            }
        case .dateAccessed:
            self.contents = self.contents.sorted { firstURL, secondURL in
                guard let firstDate = firstURL.lastAccessedDate, let secondDate = secondURL.lastAccessedDate else {
                    return false
                }
                
                return firstDate > secondDate
            }
        }
        
        self.tableView.reloadData()
    }
}

/// The ways to sort the items of a path
enum SortingWays: CaseIterable, CustomStringConvertible {
    case alphabetically
    case dateCreated
    case dateModified
    case dateAccessed
    
    var description: String {
        switch self {
        case .alphabetically:
            return "Alphabetically"
        case .dateCreated:
            return "Date created"
        case .dateModified:
            return "Date modified"
        case .dateAccessed:
            return "Date accessed"
        }
    }
}
