//
//  SubPathsTableViewController.swift
//  Santander
//
//  Created by Serena on 21/06/2022
//
	

import UIKit
import QuickLook
import UniformTypeIdentifiers

/// A table view controller showing the subpaths under a Directory, or a group
class SubPathsTableViewController: UITableViewController {
    
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
    
    /// The display name to be used as the ViewController's title
    let displayName: String
    
    /// The method of sorting
    var sortMethod: SortingWays = .alphabetically
    
    /// is this ViewController being presented as the `Favourite` paths?
    let isFavouritePathsSheet: Bool
    
    /// The current path from which items are presented
    var currentPath: URL? = nil
    
    let showInfoButton: Bool = UserPreferences.showInfoButton
    
    /// Whether or not to display the search suggestions
    var doDisplaySearchSuggestions: Bool = false
    
    /// the Directory Monitor, used to observe changes
    /// if the path is a directory
    var directoryMonitor: DirectoryMonitor?
    
    /// The label which displays that the user doesn't have permission to view a directory,
    /// or that the directory / group is empty
    /// (if those conditions apply)
    var noContentsLabel: UILabel!
    
    /// Initialize with a given path URL
    init(style: UITableView.Style = .automatic, path: URL, isFavouritePathsSheet: Bool = false) {
        self.unfilteredContents = path.contents.sorted { firstURL, secondURL in
            firstURL.lastPathComponent < secondURL.lastPathComponent
        }
        
        self.displayName = path.lastPathComponent
        self.currentPath = path
        self.isFavouritePathsSheet = isFavouritePathsSheet
        super.init(style: style)
    }
    
    /// Initialize with the given specified URLs
    init(style: UITableView.Style = .automatic, contents: [URL], title: String, isFavouritePathsSheet: Bool = false) {
        self.unfilteredContents = contents
        self.displayName = title
        self.isFavouritePathsSheet = isFavouritePathsSheet
        
        super.init(style: style)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.title = self.displayName
        
        setRightBarButton()
        
        self.navigationController?.navigationBar.prefersLargeTitles = UserPreferences.useLargeNavigationTitles
        if !contents.isEmpty {
            let searchController = UISearchController(searchResultsController: nil)
            searchController.searchBar.delegate = self
            searchController.obscuresBackgroundDuringPresentation = false
            searchController.searchResultsUpdater = self
            searchController.delegate = self
            self.tableView.keyboardDismissMode = .onDrag
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
            setupNoContentsLabel()
        }
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if self.doDisplaySearchSuggestions {
            switch section {
            case 0: return 1
            case 1, 2: return 3
            default: break
            }
        }
        
        return self.contents.count
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        self.directoryMonitor?.stopMonitoring()
    }
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        if doDisplaySearchSuggestions {
            return 3
        }
        return 1
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if doDisplaySearchSuggestions {
            let searchTextField = self.navigationItem.searchController?.searchBar.searchTextField
            let tokensCount = searchTextField?.tokens.count
            
            if (indexPath.section, indexPath.row) == (0, 0) {
                // The user wants to filter by type,
                // prompt the viewController for doing so
                let vc = TypesSelectionViewController { types in
                    // Make sure the user selected a type before we insert the search token
                    if !types.isEmpty {
                        var searchSuggestion = SearchSuggestion.displaySearchSuggestions(for: indexPath, typesToCheck: types)
                        // Set the name to the types
                        searchSuggestion.name = types.compactMap(\.localizedDescription).joined(separator: ", ")
                        searchTextField?.insertToken(searchSuggestion.searchToken, at: tokensCount ?? 0)
                    }
                }
                
                let navVC = UINavigationController(rootViewController: vc)
                
                if #available(iOS 15.0, *) {
                    navVC.sheetPresentationController?.detents = [.medium(), .large()]
                }
                
                self.present(navVC, animated: true)
                
            } else {
                searchTextField?.insertToken(SearchSuggestion.displaySearchSuggestions(for: indexPath).searchToken, at: tokensCount ?? 0)
            }
            
        } else {
            let selectedItem = contents[indexPath.row]
            goToPath(path: selectedItem)
        }
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if doDisplaySearchSuggestions {
            let cell = UITableViewCell()
            var conf = cell.defaultContentConfiguration()
            let suggestion = SearchSuggestion.displaySearchSuggestions(for: indexPath)
            conf.text = suggestion.name
            conf.image = suggestion.image
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
                    self.unfilteredContents = UserPreferences.favouritePaths.map {
                        URL(fileURLWithPath: $0)
                    }
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
                completion(true)
            } catch {
                self.errorAlert(error, title: "Couldn't remove item \(selectedItem.lastPathComponent)")
                completion(false)
            }
        }
        
        deleteAction.image = UIImage(systemName: "trash")
        
        let config = UISwipeActionsConfiguration(actions: [deleteAction, favouriteAction])
        return config
    }
    
    func makeSortMenu() -> UIMenu {
        let actions = SortingWays.allCases.map { type in
            UIAction(title: type.description, state: self.sortMethod == type ? .on : .off) { _ in
                self.sortContents(with: type)
                
                // Reload the right bar button menu after setting the type
                self.setRightBarButton()
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
        // if we can get the string contents,
        // open the Text Editor
        if let stringContents = try? String(contentsOf: path) {
            let vc = UINavigationController(rootViewController: TextFileEditorViewController(fileURL: path, contents: stringContents))
            
            vc.modalPresentationStyle = .overFullScreen
            self.present(vc, animated: true)
        } else {
            openQuickLookPreview(forURL: path)
        }
    }
    
    func openQuickLookPreview(forURL url: URL) {
        let controller = QLPreviewController()
        let shared = FilePreviewDataSource(fileURL: url)
        controller.dataSource = shared
        self.present(controller, animated: true)
    }
    
    /// Opens a path in the UI
    func goToPath(path: URL) {
        // Make sure we're opening a directory,
        // or the parent directory of the file selected (if searching)
        let dirResult = path.isDirectory ? path : path.deletingLastPathComponent()
        
        // if we're going to a directory, or a search result,
        // go to the directory path
        if path.isDirectory || (self.isSearching && dirResult != self.currentPath) {
            setPaths(forPath: dirResult)
        } else {
            self.goToFile(path: path)
        }
    }
    
    func setPaths(forPath path: URL) {
        if self.isFavouritePathsSheet {
            // if we're in the favourites sheet, just push
            // because if we set the view controllers,
            // it will go back to the previous directory
            self.navigationController?.pushViewController(SubPathsTableViewController(path: path, isFavouritePathsSheet: true), animated: true)
            return
        }
        
        let pathComponents = path.pathComponents
        var arr: [UIViewController] = []
        for (indx, _) in pathComponents.enumerated() {
            var joined = pathComponents[pathComponents.startIndex...indx].joined(separator: "/")
            if joined.hasPrefix("//") {
                joined.removeFirst()
            }
            arr.append(SubPathsTableViewController(path: URL(fileURLWithPath: joined)))
        }
        
        self.navigationController?.setViewControllers(arr, animated: true)
    }
    
    func sortContents(with filter: SortingWays) {
        self.sortMethod = filter
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
            navController.sheetPresentationController?.detents = [.medium(), .large()]
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
        
        cellConf.image = fsItem.displayImage
        
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
            // The following is the preview provider for the item
            // Being the cell row, but manually made for 2 reasons:
            // 1) Display the full path as a subtitle
            // 2) Rounded corners, which we wouldn't have if we returned previewProvider as `nil`
            let vc = UIViewController()
            vc.view = self.cellRow(forURL: item, displayFullPathAsSubtitle: true)
            let sizeFrame = vc.view.frame
            vc.preferredContentSize = CGSize(width: sizeFrame.width, height: sizeFrame.height)
            return vc
        } actionProvider: { _ in
            
            let movePath = UIAction(title: "Move to..", image: UIImage(systemName: "arrow.right")) { _ in
                let vc = PathOperationViewController(movingPath: item, sourceContentsVC: self, operationType: .move)
                self.present(UINavigationController(rootViewController: vc), animated: true)
            }
            
            let copyPath = UIAction(title: "Copy to..", image: UIImage(systemName: "doc.on.doc")) { _ in
                let vc = PathOperationViewController(movingPath: item, sourceContentsVC: self, operationType: .copy)
                self.present(UINavigationController(rootViewController: vc), animated: true)
            }
            
            let createSymlink = UIAction(title: "Create symbolic link to..", image: UIImage(systemName: "link")) { _ in
                let vc = PathOperationViewController(movingPath: item, sourceContentsVC: self, operationType: .symlink)
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
                
                alert.addTextField { textField in
                    textField.text = item.lastPathComponent
                }
                
                alert.addAction(cancelAction)
                alert.addAction(renameAction)
                self.present(alert, animated: true)
            }
            
            var children: [UIMenuElement] = [informationAction, renameAction, shareAction]
            
            if UIDevice.current.userInterfaceIdiom == .pad {
                var menu = UIMenu(title: "Add to group..", image: UIImage(systemName: "sidebar.leading"), children: [])
                
                for (index, var group) in UserPreferences.pathGroups.enumerated() where group != .default {
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
    
    func setRightBarButton() {
        let seeFavouritesAction = UIAction(title: "Favourites", image: UIImage(systemName: "star.fill")) { _ in
            let newVC = UINavigationController(rootViewController: SubPathsTableViewController(
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
    }
    
    func setupNoContentsLabel() {
        noContentsLabel = UILabel()
        
        // if we can't read the contents of the path,
        // then let the user know that we don't have permission to
        // otherwise, just say that no items were found
        if let currentPath = currentPath, !currentPath.isReadable {
            noContentsLabel.text = "Don't have permission to read directory."
        } else {
            noContentsLabel.text = "No items found."
        }
        
        noContentsLabel.font = .systemFont(ofSize: 20, weight: .medium)
        noContentsLabel.textColor = .systemGray
        noContentsLabel.textAlignment = .center
        
        self.view.addSubview(noContentsLabel)
        noContentsLabel.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            noContentsLabel.centerXAnchor.constraint(equalTo: self.view.centerXAnchor),
            noContentsLabel.centerYAnchor.constraint(equalTo: self.view.centerYAnchor)
        ])
    }
}

extension SubPathsTableViewController: DirectoryMonitorDelegate {
    func directoryMonitorDidObserveChange(directoryMonitor: DirectoryMonitor) {
        DispatchQueue.main.async {
            self.unfilteredContents = directoryMonitor.url.contents
            self.sortContents(with: self.sortMethod)
            
            if self.isSearching, let searchBar = self.navigationItem.searchController?.searchBar {
                // If we're searching,
                // update the search bar
                self.updateResults(searchBar: searchBar)
            }
            
            // if the 'No items found' or 'dont have permission to display' label isn't shown
            // and the contents are empty, setup the label
            if self.contents.isEmpty && self.noContentsLabel == nil {
                self.setupNoContentsLabel()
            } else if !self.contents.isEmpty && self.noContentsLabel != nil {
                self.noContentsLabel.removeFromSuperview()
                self.noContentsLabel = nil
            }
        }
    }
}
