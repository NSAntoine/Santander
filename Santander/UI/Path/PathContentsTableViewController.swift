//
//  PathContentsTableViewController.swift
//  Santander
//
//  Created by Serena on 21/06/2022
//
	

import UIKit
import QuickLook

/// Represents the subpaths under a Directory
class PathContentsTableViewController: UITableViewController {
    
    /// The contents of the path, unfiltered
    var unfilteredContents: [URL]
    
    /// The contents of the path, filtered by the search
    var filteredSearchContents: [URL] = []
    
    /// A Boolean representing if the user is currently searching
    var isSearching: Bool = false
    
    /// The contents of the path to show in UI
    var contents: [URL] {
        get {
            return isSearching ? filteredSearchContents : unfilteredContents
        }
    }
    
    /// The path name to be used as the ViewController's title
    let pathName: String
    
    /// The method of sorting
    var sortWay: SortingWays = .alphabetically
    
    /// is this ViewController being presented as the `Favourite` paths?
    let isFavouritePathsSheet: Bool
    
    /// The current path from which items are presented
    var currentPath: URL? = nil
    
    let showInfoButton: Bool = UserPreferences.showInfoButton
    
    /// The directory monitor, assigned and used only when currentPath is not nil
    var directoryMonitor: DirectoryMonitor? = nil
    
    /// Whether or not to display the search suggestions
    var doDisplaySearchSuggestions: Bool = false
    
    lazy var searchSuggestions: [SearchSuggestion] = [
        SearchSuggestion(name: "Symbolic Link", image: nil) { url in
            return url.isSymlink
        },
        
        SearchSuggestion(name: "File", image: nil, condition: { url in
            return !url.isDirectory
        })
        
        
    ]
    
    /// Initialize with a given path URL
    init(style: UITableView.Style = .automatic, path: URL, isFavouritePathsSheet: Bool = false) {
        self.unfilteredContents = path.contents.sorted { firstURL, secondURL in
            firstURL.lastPathComponent < secondURL.lastPathComponent
        }
        
        self.pathName = path.lastPathComponent
        self.currentPath = path
        self.isFavouritePathsSheet = isFavouritePathsSheet
        super.init(style: style)
    }
    
    /// Initialize with the given specified URLs
    init(style: UITableView.Style = .automatic, contents: [URL], title: String, isFavouritePathsSheet: Bool = false) {
        self.unfilteredContents = contents
        self.pathName = title
        self.isFavouritePathsSheet = isFavouritePathsSheet
        
        super.init(style: style)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.title = self.pathName
        
        let seeFavouritesAction = UIAction(title: "Favourites", image: UIImage(systemName: "star.fill")) { _ in
            let newVC = UINavigationController(rootViewController: PathContentsTableViewController(
                contents: UserPreferences.favouritePaths.map { URL(fileURLWithPath: $0) },
                title: "Favourites",
                isFavouritePathsSheet: true)
            )
            self.present(newVC, animated: true)
        }
        
        var menuActions: [UIMenuElement] = [makeGoToMenu(), makeSortMenu()]
        
        // if we're in the "Favourites" sheet, don't display the favourites button
        if !isFavouritePathsSheet {
            menuActions.append(seeFavouritesAction)
        }
        
        if let currentPath = currentPath {
            let showInfoAction = UIAction(title: "Info", image: .init(systemName: "info.circle")) { _ in
                self.openInfoBottomSheet(path: currentPath)
            }
            
            menuActions.insert(makeNewItemMenu(forURL: currentPath), at: 2)
            menuActions.append(showInfoAction)
            self.directoryMonitor = DirectoryMonitor(url: currentPath)
            self.directoryMonitor?.delegate = self
            directoryMonitor?.startMonitoring()
        }
        
        let settingsAction = UIAction(title: "Settings", image: UIImage(systemName: "gear")) { _ in
            self.present(UINavigationController(rootViewController: SettingsTableViewController(style: .insetGrouped)), animated: true)
        }
        menuActions.append(settingsAction)
        
        self.navigationItem.rightBarButtonItem = UIBarButtonItem(
            image: .init(systemName: "ellipsis.circle"),
            menu: .init(children: menuActions)
        )
        
        self.navigationController?.navigationBar.prefersLargeTitles = UserPreferences.useLargeNavigationTitles
        if !contents.isEmpty {
            let searchController = UISearchController(searchResultsController: nil)
            searchController.searchBar.delegate = self
            searchController.obscuresBackgroundDuringPresentation = false
            searchController.searchResultsUpdater = self
            searchController.delegate = self
            self.navigationItem.hidesSearchBarWhenScrolling = !UserPreferences.alwaysShowSearchBar
            if let currentPath = currentPath {
                searchController.searchBar.scopeButtonTitles = [currentPath.lastPathComponent, "Subdirectories"]
            }
            self.navigationItem.searchController = searchController
        }
        
        tableView.dragInteractionEnabled = true
        tableView.dropDelegate = self
        tableView.dragDelegate = self
        
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
        if self.doDisplaySearchSuggestions {
            return self.searchSuggestions.count
        }
        
        return self.contents.count
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        // Stop monitoring for directory changes once the view will disappear
        directoryMonitor?.stopMonitoring()
    }
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if doDisplaySearchSuggestions {
            let searchTextField = self.navigationItem.searchController?.searchBar.searchTextField
            let tokensCount = searchTextField?.tokens.count
            searchTextField?.insertToken(searchSuggestions[indexPath.row].searchToken, at: tokensCount ?? 0)
        } else {
            let selectedItem = contents[indexPath.row]
            goToPath(path: selectedItem)
        }
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if doDisplaySearchSuggestions {
            let cell = UITableViewCell()
            var conf = cell.defaultContentConfiguration()
            conf.text = searchSuggestions[indexPath.row].name
            conf.image = searchSuggestions[indexPath.row].image
            cell.contentConfiguration = conf
            return cell
        } else {
            return self.cellRow(
                forURL: contents[indexPath.row],
                displayFullPathAsSubtitle: self.isSearching || self.isFavouritePathsSheet
            )
        }
    }
    
    override func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        
        let selectedItem = self.contents[indexPath.row]
        let itemAlreadyFavourited = UserPreferences.favouritePaths.contains(selectedItem.path)
        let favouriteAction = UIContextualAction(style: .normal, title: nil) { _, _, handler in
            // if the item already exists, remove it
            if itemAlreadyFavourited {
                UserPreferences.favouritePaths.removeAll { $0 == selectedItem.path }
                
                // if we're in the favourites sheet, reload the table
                if self.isFavouritePathsSheet {
                    self.unfilteredContents = UserPreferences.favouritePaths.map { URL(fileURLWithPath: $0) }
                    self.tableView.deleteRows(at: [indexPath], with: .automatic)
                }
            } else {
                // otherwise, append it
                UserPreferences.favouritePaths.append(selectedItem.path)
            }
            
            handler(true)
        }
        
        favouriteAction.backgroundColor = .systemBlue
        favouriteAction.image = itemAlreadyFavourited ? UIImage(systemName: "star.fill") : UIImage(systemName: "star")

        let deleteAction = UIContextualAction(style: .destructive, title: nil) { _, _, completion in
            do {
                try FileManager.default.removeItem(at: selectedItem)
                self.unfilteredContents.removeAll { $0 == selectedItem }
                self.tableView.deleteRows(at: [indexPath], with: .automatic)
                completion(true)
            } catch {
                self.errorAlert(error, title: "Couldn't remove item \(selectedItem.lastPathComponent)")
                completion(false)
            }
        }
        
        deleteAction.image = UIImage(systemName: "trash")
        
        let config = UISwipeActionsConfiguration(actions: [deleteAction, favouriteAction])
        config.performsFirstActionWithFullSwipe = false
        return config
    }
    
    func makeSortMenu() -> UIMenu {
        let actions = SortingWays.allCases.map { type in
            UIAction(title: type.description) { _ in
                self.sortContents(with: type)
        }}
        
        let menu = UIMenu(title: "Sort by..", image: UIImage(systemName: "filemenu.and.selection"))
        return menu.replacingChildren(actions)
    }
    
    func makeNewItemMenu(forURL url: URL) -> UIMenu {
        let newFile = UIAction(title: "File", image: UIImage(systemName: "doc")) { _ in
            self.presentAlertAndCreate(type: .file, forURL: url)
        }
        
        let newFolder = UIAction(title: "Folder", image: UIImage(systemName: "folder")) { _ in
            self.presentAlertAndCreate(type: .directory, forURL: url)
        }
        
        return UIMenu(title: "New..", image: UIImage(systemName: "plus"), children: [newFile, newFolder])
    }
    
    
    // A UIMenu containing different, common, locations to go to, as well as an option
    // to go to a specified URL
    func makeGoToMenu() -> UIMenu {
        var menu = UIMenu(title: "Go to..", image: UIImage(systemName: "arrow.right"))
        
        let commonLocations: [String: URL?] = [
            "Home" : .home,
            "Applications": FileManager.default.urls(for: .applicationDirectory, in: .userDomainMask).first,
            "Documents" : FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first,
            "Downloads": FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first,
            "/ (Root)" : .root,
            "var": URL(fileURLWithPath: "/var")
        ]
        
        for (locationName, locationURL) in commonLocations {
            guard let locationURL = locationURL, FileManager.default.fileExists(atPath: locationURL.path) else {
                continue
            }
            
            menu = menu.appending(UIAction(title: locationName, handler: { _ in
                self.goToPath(path: locationURL)
            }))
        }
        
        let otherLocationAction = UIAction(title: "Other..") { _ in
            let alert = UIAlertController(title: "Other Location", message: "Type the URL of the other path you want to go to", preferredStyle: .alert)
            
            alert.addTextField { textfield in
                textfield.placeholder = "url.."
            }
                
            let goAction = UIAlertAction(title: "Go", style: .default) { _ in
                guard let text = alert.textFields?.first?.text, FileManager.default.fileExists(atPath: text) else {
                    self.errorAlert("URL inputted must be valid and must exist", title: "Error")
                    return
                }
                
                let url = URL(fileURLWithPath: text)
                self.goToPath(path: url)
            }
            
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
            alert.addAction(goAction)
            alert.preferredAction = goAction
            self.present(alert, animated: true)
        }
        
        menu = menu.appending(otherLocationAction)
        
        return menu
    }
    
    
    func goToFile(path: URL) {
        let controller = QLPreviewController()
        let shared = FilePreviewDataSource(fileURL: path)
        controller.dataSource = shared
        self.present(controller, animated: true)
    }
    
    /// Opens a path in the UI
    func goToPath(path: URL) {
        // if we're going to a directory, or a search result,
        // go to the directory path
        if path.isDirectory || self.isSearching {
            // Make sure we're opening a directory,
            // or the parent directory of the file selected
            let dirToOpen = path.isDirectory ? path : path.deletingLastPathComponent()
            self.navigationController?.pushViewController(PathContentsTableViewController(path: dirToOpen), animated: true)
        } else {
            self.goToFile(path: path)
        }
    }
    
    func sortContents(with filter: SortingWays) {
        self.unfilteredContents = self.contents.sorted { firstURL, secondURL in
            switch filter {
            case .alphabetically:
                return firstURL.lastPathComponent < secondURL.lastPathComponent
            case .size:
                guard let firstSize = firstURL.size, let secondSize = secondURL.size else {
                    return false
                }
                
                return firstSize > secondSize
            case .type:
                return firstURL.contentType == secondURL.contentType
            case .dateCreated:
                guard let firstDate = firstURL.creationDate, let secondDate = secondURL.creationDate else {
                    return false
                }
                
                return firstDate < secondDate
            case .dateModified:
                guard let firstDate = firstURL.lastModifiedDate, let secondDate = secondURL.lastModifiedDate else {
                    return false
                }
                
                return firstDate < secondDate
            case .dateAccessed:
                guard let firstDate = firstURL.lastAccessedDate, let secondDate = secondURL.lastAccessedDate else {
                    return false
                }
                
                return firstDate < secondDate
            }
        }
        
        self.tableView.reloadData()
    }
    
    /// Opens the information bottom sheet for a specified path
    func openInfoBottomSheet(path: URL) {
        let navController = UINavigationController(
            rootViewController: PathInformationTableView(style: .insetGrouped, path: path)
        )
        
        if #available(iOS 15.0, *) {
            navController.modalPresentationStyle = .pageSheet
            
            if let sheetController = navController.sheetPresentationController {
                sheetController.detents = [.medium(), .large()]
            }
        }
        
        self.present(navController, animated: true)
    }
    
    override func tableView(_ tableView: UITableView, accessoryButtonTappedForRowWith indexPath: IndexPath) {
        self.openInfoBottomSheet(path: contents[indexPath.row])
    }
    
    /// Returns the cell row to be used
    func cellRow(forURL fsItem: URL, displayFullPathAsSubtitle: Bool = false) -> UITableViewCell {
        let cell: UITableViewCell
        
        // If we should display the full path as a subtitle, init with the style as `subtitle`
        if displayFullPathAsSubtitle {
            cell = UITableViewCell(style: .subtitle, reuseIdentifier: nil)
        } else {
            cell = UITableViewCell()
        }
        
        var cellConf = cell.defaultContentConfiguration()
        
        cellConf.text = fsItem.lastPathComponent
        
        // if the item starts is a dotfile / dotdirectory
        // ie, .conf or .zshrc,
        // display the label as gray
        if fsItem.lastPathComponent.first == "." {
            cellConf.textProperties.color = .gray
            cellConf.secondaryTextProperties.color = .gray
        }
        
        if displayFullPathAsSubtitle {
            cellConf.secondaryText = fsItem.path // Display full path as the subtitle text if we should
        }
        
        if fsItem.isDirectory {
            // Display the disclosureIndicator only for directories
            cellConf.image = UIImage(systemName: "folder.fill")
        } else {
            // TODO: we should display the icon for files with https://indiestack.com/2018/05/icon-for-file-with-uikit/
            cellConf.image = UIImage(systemName: "doc.fill")
        }
        
        if showInfoButton {
            cell.accessoryType = .detailDisclosureButton
        } else if fsItem.isDirectory {
            cell.accessoryType = .disclosureIndicator
        }
        
        cell.contentConfiguration = cellConf
        return cell
    }
        
    override func tableView(_ tableView: UITableView, contextMenuConfigurationForRowAt indexPath: IndexPath, point: CGPoint) -> UIContextMenuConfiguration? {
        
        if doDisplaySearchSuggestions {
            return nil // No context menu for search suggestions
        }
        
        let item = contents[indexPath.row]
        return UIContextMenuConfiguration(identifier: nil) {
            return nil
        } actionProvider: { _ in
            
            let movePath = UIAction(title: "Move to..", image: UIImage(systemName: "arrow.right")) { _ in
                let vc = PathOperationViewController(movingPath: item, sourceContentsVC: self, operationType: .move, startingPath: self.currentPath ?? .root)
                self.present(UINavigationController(rootViewController: vc), animated: true)
            }
            
            let copyPath = UIAction(title: "Copy to..", image: UIImage(systemName: "doc.on.doc")) { _ in
                let vc = PathOperationViewController(movingPath: item, sourceContentsVC: self, operationType: .copy, startingPath: self.currentPath ?? .root)
                self.present(UINavigationController(rootViewController: vc), animated: true)
            }
            
            let createSymlink = UIAction(title: "Create symbolic link to..") { _ in
                let vc = PathOperationViewController(movingPath: item, sourceContentsVC: self, operationType: .symlink, startingPath: self.currentPath ?? .root)
                self.present(UINavigationController(rootViewController: vc), animated: true)
            }
            
            let pasteboardOptions = UIMenu(options: .displayInline, children: self.makePasteboardMenuElements(for: item))
            let operationItemsMenu = UIMenu(options: .displayInline, children: [movePath, copyPath, createSymlink])
            let informationAction = UIAction(title: "Info", image: UIImage(systemName: "info.circle")) { _ in
                self.openInfoBottomSheet(path: item)
            }
            
            let shareAction = UIAction(title: "Share", image: UIImage(systemName: "square.and.arrow.up")) { _ in
                let vc = UIActivityViewController.init(activityItems: [item], applicationActivities: [])
                vc.popoverPresentationController?.sourceView = self.view
                vc.popoverPresentationController?.sourceRect = CGRect(x: self.view.bounds.midX, y: self.view.bounds.midY, width: 0, height: 0)
                self.present(vc, animated: true)
            }
            
            let renameAction = UIAction(title: "Rename", image: UIImage(systemName: "rectangle.and.pencil.and.ellipsis")) { _ in
                let alert = UIAlertController(title: "Rename", message: nil, preferredStyle: .alert)
                let cancelAction = UIAlertAction(title: "Cancel", style: .cancel)
                let renameAction = UIAlertAction(title: "Rename", style: .default) { _ in
                    guard let name = alert.textFields?.first?.text else {
                        return
                    }
                    
                    do {
                        let newPath = item.deletingLastPathComponent().appendingPathComponent(name)
                        try FileManager.default.moveItem(at: item, to: newPath)
                    } catch {
                        self.errorAlert(error, title: "Unable to rename \(item.lastPathComponent)")
                    }
                }
                alert.addTextField()
                alert.addAction(cancelAction)
                alert.addAction(renameAction)
                self.present(alert, animated: true)
            }
            
            var children: [UIMenuElement] = [informationAction, renameAction, shareAction]
            
            if UIDevice.current.userInterfaceIdiom == .pad {
                var menu = UIMenu(title: "Add to group..", image: UIImage(systemName: "sidebar.leading"), children: [])
                
                for (index, var group) in UserPreferences.pathGroups.enumerated() {
                    let addAction = UIAction(title: group.name) { _ in
                        UserPreferences.pathGroups.remove(at: index)
                        group.paths.append(item)
                        UserPreferences.pathGroups.append(group)
                    }
                    
                    menu = menu.appending(addAction)
                }
                
                children.append(menu)
            }
            
            let deleteAction = UIAction(title: "Delete", image: UIImage(systemName: "trash"), attributes: .destructive) { _ in
                do {
                    try FileManager.default.removeItem(at: item)
                } catch {
                    self.errorAlert(error, title: "Unable to delete item")
                }
            }
            
            children.append(contentsOf: [operationItemsMenu, pasteboardOptions])
            children.append(contentsOf: [UIMenu(options: .displayInline, children: [deleteAction])])
            return UIMenu(children: children)
        }
    }
    
    func makePasteboardMenuElements(for url: URL) -> [UIMenuElement] {
        let copyName = UIAction(title: "Copy name") { _ in
            UIPasteboard.general.string = url.lastPathComponent
        }
        
        let copyPath = UIAction(title: "Copy path") { _ in
            UIPasteboard.general.string = url.path
        }
        
        return [copyName, copyPath]
    }
}

extension PathContentsTableViewController: DirectoryMonitorDelegate {
    func directoryMonitorDidObserveChange(directoryMonitor: DirectoryMonitor) {
        if self.unfilteredContents != directoryMonitor.url.contents {
            DispatchQueue.main.async {
                self.unfilteredContents = directoryMonitor.url.contents
                self.tableView.reloadData()
            }
        }
    }
}
