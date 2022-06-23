//
//  PathTableViewController.swift
//  Santander
//
//  Created by Serena on 21/06/2022
//
	

import UIKit
import UniformTypeIdentifiers

/// Represents the subpaths under a Directory
class PathContentsTableViewController: UITableViewController {
    
    /// The contents of the path, unfiltered
    var unfilteredContents: [URL]
    
    /// The contents of the path, filtered by the search
    var filteredSearchContents: [URL] = []
    
    /// A Boolean representing if the user is currently searching
    var isSeaching: Bool = false
    
    /// The contents of the path to show in UI
    var contents: [URL] {
        get {
            return isSeaching ? filteredSearchContents : unfilteredContents
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
    
    /// Initialize with a given path URL
    init(style: UITableView.Style = .plain, path: URL, isFavouritePathsSheet: Bool = false) {
        self.unfilteredContents = path.contents.sorted { firstURL, secondURL in
            firstURL.lastPathComponent < secondURL.lastPathComponent
        }
        
        self.pathName = path.lastPathComponent
        self.currentPath = path
        self.isFavouritePathsSheet = isFavouritePathsSheet
        super.init(style: style)
    }
    
    /// Initialize with the given specified URLs
    init(style: UITableView.Style = .plain, contents: [URL], title: String, isFavouritePathsSheet: Bool = false) {
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
        
        if let currentPath, currentPath.lastPathComponent != "/" {
            self.navigationItem.backBarButtonItem = UIBarButtonItem(
                title: currentPath.lastPathComponent,
                image: nil, primaryAction: nil, menu: nil
            )
        }
        
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
        
        if let currentPath {
            let showInfoAction = UIAction(title: "Info", image: .init(systemName: "info.circle")) { _ in
                self.openInfoBottomSheet(path: currentPath)
            }
            
            menuActions.append(showInfoAction)
        }
        
        self.navigationItem.rightBarButtonItem = UIBarButtonItem(
            image: .init(systemName: "ellipsis.circle.fill"),
            menu: .init(children: menuActions)
        )
        
        // To-do: a settings for this & other options
        self.navigationController?.navigationBar.prefersLargeTitles = /*UserPreferences.useLargeNavigationTitles*/ true
        if !contents.isEmpty {
            let searchController = UISearchController(searchResultsController: nil)
            searchController.searchBar.delegate = self
            searchController.obscuresBackgroundDuringPresentation = false
            if let currentPath {
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
        return self.contents.count
    }
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    override func tableView(_ tableView: UITableView, accessoryButtonTappedForRowWith indexPath: IndexPath) {
        openInfoBottomSheet(path: contents[indexPath.row])
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let selectedItem = contents[indexPath.row]
        goToPath(path: selectedItem)
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell: UITableViewCell
        
        // If the current ViewController is being presented as the Favourites sheet or the user is searching
        // initialize as a view cell with the style of a subtitle
        if isFavouritePathsSheet || self.isSeaching {
            cell = UITableViewCell(style: .subtitle, reuseIdentifier: nil)
        } else {
            cell = UITableViewCell()
        }
        
        var cellConf = cell.defaultContentConfiguration()
        
        let fsItem = contents[indexPath.row]
        cellConf.text = fsItem.lastPathComponent
        
        // if the item starts is a dotfile / dotdirectory
        // ie, .conf or .zshrc,
        // display the label as gray
        if fsItem.lastPathComponent.first == "." {
            cellConf.textProperties.color = .gray
            cellConf.secondaryTextProperties.color = .gray
        }
        
        if isFavouritePathsSheet || self.isSeaching {
            cellConf.secondaryText = fsItem.path // Display full path if we're in the Favourites sheet or searching
        }
        
        if fsItem.isDirectory {
            cellConf.image = UIImage(systemName: "folder.fill")
        } else {
            // TODO: we should display the icon for files with https://indiestack.com/2018/05/icon-for-file-with-uikit/
            cellConf.image = UIImage(systemName: "doc.fill")
        }
        
        // If the item is a file, show just the "i" icon,
        // otherwise show the icon & a disclosure button
        cell.accessoryType = .detailDisclosureButton 
        cell.contentConfiguration = cellConf
        return cell
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
        
        favouriteAction.backgroundColor = .systemYellow
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
    
    // A UIMenu containing different, common, locations to go to, as well as an option
    // to go to a specified URL
    func makeGoToMenu() -> UIMenu {
        var menu = UIMenu(title: "Go to..")
        
        let commonLocations: [String: URL?] = [
            "Home" : URL(fileURLWithPath: NSHomeDirectory()),
            "Applications": FileManager.default.urls(for: .applicationDirectory, in: .userDomainMask).first,
            "Documents" : FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first,
            "Downloads": FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first,
            "Root (/)" : URL(fileURLWithPath: "/"),
            "var": URL(fileURLWithPath: "/var")
        ]
        
        for (locationName, locationURL) in commonLocations {
            guard let locationURL, FileManager.default.fileExists(atPath: locationURL.path) else {
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
                guard let text = alert.textFields?.first?.text else {
                    self.errorAlert("Valid path must be input", title: "Error")
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
    
    
    /// Opens a path in the UI
    func goToPath(path: URL) {
        self.navigationController?.pushViewController(PathContentsTableViewController(path: path), animated: true)
    }
    
    func sortContents(with filter: SortingWays) {
        switch filter {
        case .alphabetically:
            self.unfilteredContents = self.contents.sorted { firstURL, secondURL in
                firstURL.lastPathComponent < secondURL.lastPathComponent
            }
        case .dateCreated:
            self.unfilteredContents = self.contents.sorted { firstURL, secondURL in
                guard let firstDate = firstURL.creationDate, let secondDate = secondURL.creationDate else {
                    return false
                }
                
                return firstDate > secondDate
            }
        case .dateModified:
            self.unfilteredContents = self.contents.sorted { firstURL, secondURL in
                guard let firstDate = firstURL.lastModifiedDate, let secondDate = secondURL.lastModifiedDate else {
                    return false
                }
                
                return firstDate > secondDate
            }
        case .dateAccessed:
            self.unfilteredContents = self.contents.sorted { firstURL, secondURL in
                guard let firstDate = firstURL.lastAccessedDate, let secondDate = secondURL.lastAccessedDate else {
                    return false
                }
                
                return firstDate > secondDate
            }
        case .size:
            self.unfilteredContents = self.contents.sorted { firstURL, secondURL in
                guard let firstSize = firstURL.size, let secondSize = secondURL.size else {
                    return false
                }
                
                return firstSize > secondSize
            }
        }
        
        self.tableView.reloadData()
    }
    
    /// Opens the information bottom sheet for a specified path
    func openInfoBottomSheet(path: URL) {
        let navController = UINavigationController(
            rootViewController: PathInformationTableView(style: .insetGrouped, path: path)
        )
        
        navController.modalPresentationStyle = .pageSheet
        
        if let sheetController = navController.sheetPresentationController {
            sheetController.detents = [.medium(), .large()]
        }
        
        self.present(navController, animated: true)
    }
}

/// The ways to sort the contents
enum SortingWays: CaseIterable, CustomStringConvertible {
    case alphabetically
    case size
    case dateCreated
    case dateModified
    case dateAccessed
    
    var description: String {
        switch self {
        case .alphabetically:
            return "Alphabetical order"
        case .size:
            return "Size"
        case .dateCreated:
            return "Date created"
        case .dateModified:
            return "Date modified"
        case .dateAccessed:
            return "Date accessed"
        }
    }
}

extension PathContentsTableViewController: UITableViewDropDelegate, UITableViewDragDelegate {
    
    func tableView(_ tableView: UITableView, performDropWith coordinator: UITableViewDropCoordinator) {
        
        guard let currentPath = self.currentPath else {
            return
        }
        
        let destIndexPath: IndexPath
        if let indexPath = coordinator.destinationIndexPath {
            destIndexPath = indexPath
        } else {
            let section = tableView.numberOfSections - 1
            destIndexPath = IndexPath(row: tableView.numberOfRows(inSection: section), section: section)
        }
        
        coordinator.items.first?.dragItem.itemProvider.loadFileRepresentation(forTypeIdentifier: "public.content") { url, err in
            guard let url = url, err == nil else {
                DispatchQueue.main.async {
                    self.errorAlert("Error: \(err?.localizedDescription ?? "Unknown")", title: "Failed to import file")
                }
                return
            }
            
            let newPath = currentPath
                .appendingPathComponent(url.lastPathComponent)
            
            do {
                try FileManager.default.copyItem(at: url, to: newPath)
                DispatchQueue.main.async {
                    self.unfilteredContents = currentPath.contents
                    tableView.insertRows(at: [destIndexPath], with: .automatic)
                }
            } catch {
                DispatchQueue.main.async {
                    self.errorAlert("Error: \(error.localizedDescription)", title: "Failed to copy item")
                }
            }
            
        }
    }
    
    func tableView(_ tableView: UITableView, canHandle session: UIDropSession) -> Bool {
        return currentPath != nil
    }
    
    func tableView(_ tableView: UITableView, itemsForBeginning session: UIDragSession, at indexPath: IndexPath) -> [UIDragItem] {
        let selectedItem = contents[indexPath.row]
        guard !selectedItem.isDirectory else {
            return []
        }
        
        let itemProvider = NSItemProvider()
        
        let typeID = UTType(filenameExtension: selectedItem.pathExtension)?.identifier ?? "public.content"
        
        itemProvider.registerFileRepresentation(
            forTypeIdentifier: typeID,
            visibility: .all) { completion in
                completion(selectedItem, true, nil)
                return nil
            }
        
        return [
            UIDragItem(itemProvider: itemProvider)
        ]
    }
}

extension PathContentsTableViewController: UISearchBarDelegate {
    
    func cancelSearch() {
        self.filteredSearchContents = []
        self.isSeaching = false
        tableView.reloadData()
    }
    
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        updateResults(searchBar: searchBar)
    }
    
    func searchBarCancelButtonClicked(_ searchBar: UISearchBar) {
        cancelSearch()
    }
    
    func searchBar(_ searchBar: UISearchBar, selectedScopeButtonIndexDidChange selectedScope: Int) {
        updateResults(searchBar: searchBar)
    }
    
    func updateResults(searchBar: UISearchBar) {
        guard let searchText = searchBar.text, !searchText.isEmpty else {
            cancelSearch()
            return
        }
        
        self.isSeaching = true
        let results: [URL]
        if let currentPath, searchBar.selectedScopeButtonIndex == 1 {
            results = FileManager.default.enumerator(at: currentPath, includingPropertiesForKeys: [])?.allObjects.compactMap { $0 as? URL } ?? []
        } else {
            results = unfilteredContents
        }
        
        // Eventually, I want to make it so that the user can choose between if they want to search for the file name
        // and for the path
        self.filteredSearchContents = results.filter { $0.lastPathComponent.localizedCaseInsensitiveContains(searchText) }
        tableView.reloadData()
    }
}
