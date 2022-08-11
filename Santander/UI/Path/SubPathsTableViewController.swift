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
    
    /// The contents of the path, filtered by the search or hiding dotfiles
    var filteredSearchContents: [URL] = []
    
    /// The items selected by the user while editing
    var selectedItems: [URL] = []
    
    /// A Boolean representing if the user is currently searching
    var isSearching: Bool = false
    
    /// The contents of the path to show in UI
    var contents: [URL] {
        get {
            return filteredSearchContents.isEmpty && !self.isSearching ? unfilteredContents : filteredSearchContents
        }
    }
    
    /// The method of sorting
    var sortMethod: PathsSortMethods = .userPrefered ?? .alphabetically {
        willSet {
            UserDefaults.standard.set(newValue.rawValue, forKey: "SubPathsSortMode")
            sortContents()
        }
    }
    
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
    
    /// Whether or not to display files beginning with a dot in their names
    var displayHiddenFiles: Bool = UserPreferences.displayHiddenFiles {
        didSet {
            showOrHideDotfiles()
            
            UserPreferences.displayHiddenFiles = self.displayHiddenFiles
        }
    }
    
    typealias DataSourceType = UITableViewDiffableDataSource<Int, SubPathsRowItem>
    lazy var dataSource = DataSourceType(tableView: self.tableView) { tableView, indexPath, itemIdentifier in
        switch itemIdentifier {
        case .path(let url):
            return self.pathCellRow(forURL: url, displayFullPathAsSubtitle: self.isSearching || self.isFavouritePathsSheet)
        case .searchSuggestion(let suggestion):
            return self.searchSuggestionCellRow(suggestion: suggestion)
        }
    }
    
    /// Returns the SubPathsTableViewController for favourite paths
    class func Favorites() -> SubPathsTableViewController {
        return SubPathsTableViewController(
            contents: UserPreferences.favouritePaths.map { URL(fileURLWithPath: $0) },
            title: "Favorites",
            isFavouritePathsSheet: true)
    }
    
    /// Initialize with a given path URL
    init(style: UITableView.Style = .userPreferred, path: URL, isFavouritePathsSheet: Bool = false) {
        self.unfilteredContents = self.sortMethod.sorting(URLs: path.contents, sortOrder: .userPreferred)
        self.currentPath = path
        self.isFavouritePathsSheet = isFavouritePathsSheet
        
        super.init(style: style)
        self.title = path.lastPathComponent
    }
    
    /// Initialize with the given specified URLs
    init(style: UITableView.Style = .userPreferred, contents: [URL], title: String, isFavouritePathsSheet: Bool = false) {
        self.unfilteredContents = self.sortMethod.sorting(URLs: contents, sortOrder: .userPreferred)
        self.isFavouritePathsSheet = isFavouritePathsSheet
        
        super.init(style: style)
        self.title = title
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setRightBarButton()
        
        if !self.displayHiddenFiles {
            showOrHideDotfiles()
        }
        
        if let currentPath = self.currentPath {
            self.directoryMonitor = DirectoryMonitor(url: currentPath)
            self.directoryMonitor?.delegate = self
            directoryMonitor?.startMonitoring()
        }
        
        self.navigationController?.navigationBar.prefersLargeTitles = UserPreferences.useLargeNavigationTitles
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
#if compiler(>=5.7)
        if #available(iOS 16.0, *), UIDevice.current.userInterfaceIdiom == .pad {
            self.navigationItem.style = .browser
            self.navigationItem.renameDelegate = self
        }
#endif
        
        tableView.dragInteractionEnabled = true
        tableView.dropDelegate = self
        tableView.dragDelegate = self
        tableView.dataSource = self.dataSource
        showPaths()
        
        if self.contents.isEmpty {
            setupNoContentsLabel()
        }
    }
    
    /// Setup the snapshot to show the paths given
    func showPaths(animatingDifferences: Bool = false) {
        self.doDisplaySearchSuggestions = false
        var snapshot = dataSource.snapshot()
        snapshot.deleteAllItems()
        snapshot.deleteSections([1, 2])
        
        snapshot.appendSections([0])
        snapshot.appendItems(SubPathsRowItem.fromPaths(contents))
        dataSource.apply(snapshot, animatingDifferences: animatingDifferences)
    }
    
    /// Show the search suggestions
    func switchToSearchSuggestions() {
        doDisplaySearchSuggestions = true
        var snapshot = dataSource.snapshot()
        snapshot.deleteAllItems()
        snapshot.appendSections([0, 1, 2])
        snapshot.appendItems([
            .searchSuggestion(.displaySearchSuggestions(for: [0, 0]))
        ], toSection: 0)
        
        snapshot.appendItems([
            .searchSuggestion(.displaySearchSuggestions(for: [1, 0])),
            .searchSuggestion(.displaySearchSuggestions(for: [1, 1])),
            .searchSuggestion(.displaySearchSuggestions(for: [1, 2]))
        ], toSection: 1)
        
        snapshot.appendItems([
            .searchSuggestion(.displaySearchSuggestions(for: [2, 0])),
            .searchSuggestion(.displaySearchSuggestions(for: [2, 1])),
            .searchSuggestion(.displaySearchSuggestions(for: [2, 2])),
        ])
        
        dataSource.apply(snapshot, animatingDifferences: false)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        self.directoryMonitor?.stopMonitoring()
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if self.isEditing {
            selectedItems.append(contents[indexPath.row])
            setupOrUpdateToolbar()
            return
        }
        
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
                
                self.present(navVC, animated: true)
                
            } else {
                searchTextField?.insertToken(SearchSuggestion.displaySearchSuggestions(for: indexPath).searchToken, at: tokensCount ?? 0)
            }
            
        } else {
            let selectedItem = contents[indexPath.row]
            goToPath(path: selectedItem)
        }
    }
    
    override func tableView(_ tableView: UITableView, didDeselectRowAt indexPath: IndexPath) {
        let selected = contents[indexPath.row]
        selectedItems.removeAll { path in
            path == selected
        }
        
        setupOrUpdateToolbar()
    }
    
    override func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        
        let selectedItem = self.contents[indexPath.row]
        let itemAlreadyFavourited = UserPreferences.favouritePaths.contains(selectedItem.path)
        let favouriteAction = UIContextualAction(style: .normal, title: nil) { _, _, handler in
            // if the item already exists, remove it
            if itemAlreadyFavourited {
                UserPreferences.favouritePaths.removeAll { $0 == selectedItem.path }
                
                // if we're in the Favorites sheet, reload the table
                if self.isFavouritePathsSheet {
                    self.unfilteredContents = UserPreferences.favouritePaths.map {
                        URL(fileURLWithPath: $0)
                    }
                    
                    var snapshot = self.dataSource.snapshot()
                    snapshot.deleteItems([.path(selectedItem)])
                    self.dataSource.apply(snapshot)
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
            self.deleteURL(selectedItem) { didSucceed in
                completion(didSucceed)
            }
        }
        
        deleteAction.image = UIImage(systemName: "trash")
        
        let config = UISwipeActionsConfiguration(actions: [deleteAction, favouriteAction])
        return config
    }
    
    func makeSortMenu() -> UIMenu {
        let actions: [UIMenuElement] = PathsSortMethods.allCases.map { type in
            let typeIsSelected = self.sortMethod == type
            return UIAction(
                title: type.description,
                image: typeIsSelected ? UIImage(systemName: SortOrder.userPreferred.imageSymbolName) : nil,
                state: typeIsSelected ? .on : .off) { _ in
                    // if the user selected the already selected type,
                    // change the sort order
                    if typeIsSelected {
                        UserDefaults.standard.set(SortOrder.userPreferred.toggling().rawValue, forKey: "SortOrder")
                        self.sortContents()
                    } else {
                        // otherwise change the sort method itself
                        self.sortMethod = type
                    }
                    
                    // Reload the right bar button menu after setting the type
                    self.setRightBarButton()
                }
        }
        
        let menu = UIMenu(title: "Sort by..", image: UIImage(systemName: "arrow.up.arrow.down"), children: actions)
        if #available(iOS 15.0, *) {
            menu.subtitle = self.sortMethod.description
        }
        
        return menu
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
        if let audioVC = try? AudioPlayerViewController(fileURL: path) {
            let navVC = UINavigationController(rootViewController: audioVC)
            navVC.modalPresentationStyle = .fullScreen
            self.present(navVC, animated: true)
        } else if let editorVC = try? TextFileEditorViewController(fileURL: path) {
            let vc = UINavigationController(rootViewController: editorVC)
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
    func goToPath(path: URL, pushingToSplitViewVC: Bool = false) {
        // Make sure we're opening a directory,
        // or the parent directory of the file selected (if searching)
        let dirResult = path.isDirectory ? path : path.deletingLastPathComponent()
        
        // if we're going to a directory, or a search result,
        // go to the directory path
        if path.isDirectory || (self.isSearching && dirResult != self.currentPath) {
            let vc = SubPathsTableViewController(path: path, isFavouritePathsSheet: self.isFavouritePathsSheet)
            if pushingToSplitViewVC {
                self.splitViewController?.setViewController(vc, for: .secondary)
            } else {
                self.navigationController?.pushViewController(vc, animated: true)
            }
        } else {
            self.goToFile(path: path)
        }
    }
    
    func sortContents() {
        self.unfilteredContents = sortMethod.sorting(URLs: unfilteredContents, sortOrder: .userPreferred)
        showOrHideDotfiles(animatingDifferences: true)
    }
    
    /// Opens the information bottom sheet for a specified path
    func openInfoBottomSheet(path: URL) {
        let navController = UINavigationController(
            rootViewController: PathInformationTableViewController(style: .insetGrouped, path: path)
        )
        
        if #available(iOS 15.0, *) {
            navController.sheetPresentationController?.detents = [.medium(), .large()]
        }
        
        self.present(navController, animated: true)
    }
    
    override func tableView(_ tableView: UITableView, accessoryButtonTappedForRowWith indexPath: IndexPath) {
        self.openInfoBottomSheet(path: contents[indexPath.row])
    }
    
    /// Returns the cell row to be used for a search suggestion
    func searchSuggestionCellRow(suggestion: SearchSuggestion) -> UITableViewCell {
        let cell = UITableViewCell()
        var conf = cell.defaultContentConfiguration()
        conf.text = suggestion.name
        conf.image = suggestion.image
        cell.contentConfiguration = conf
        return cell
    }
    
    /// Returns the cell row to be used to display a path
    func pathCellRow(forURL fsItem: URL, displayFullPathAsSubtitle: Bool = false) -> UITableViewCell {
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
            vc.view = self.pathCellRow(forURL: item, displayFullPathAsSubtitle: true)
            vc.view.backgroundColor = .clear
            let sizeFrame = vc.view.frame
            vc.preferredContentSize = CGSize(width: sizeFrame.width, height: sizeFrame.height)
            return vc
        } actionProvider: { _ in
            
            let movePath = UIAction(title: "Move to..", image: UIImage(systemName: "arrow.right")) { _ in
                let vc = PathOperationViewController(paths: [item], operationType: .move)
                self.present(UINavigationController(rootViewController: vc), animated: true)
            }
            
            let copyPath = UIAction(title: "Copy to..", image: UIImage(systemName: "doc.on.doc")) { _ in
                let vc = PathOperationViewController(paths: [item], operationType: .copy)
                self.present(UINavigationController(rootViewController: vc), animated: true)
            }
            
            let createSymlink = UIAction(title: "Create symbolic link to..", image: UIImage(systemName: "link")) { _ in
                let vc = PathOperationViewController(paths: [item], operationType: .symlink)
                self.present(UINavigationController(rootViewController: vc), animated: true)
            }
            
            let pasteboardOptions = UIMenu(options: .displayInline, children: self.makePasteboardMenuElements(for: item))
            let operationItemsMenu = UIMenu(options: .displayInline, children: [movePath, copyPath, createSymlink])
            let informationAction = UIAction(title: "Info", image: UIImage(systemName: "info.circle")) { _ in
                self.openInfoBottomSheet(path: item)
            }
            
            let shareAction = UIAction(title: "Share", image: UIImage(systemName: "square.and.arrow.up")) { _ in
                self.presentShareAction(items: [item])
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
                
                for (index, group) in UserPreferences.pathGroups.enumerated() where group != .default {
                    let addAction = UIAction(title: group.name) { _ in
                        UserPreferences.pathGroups[index].paths.append(item)
                    }
                    
                    menu = menu.appending(addAction)
                }
                
                children.append(menu)
            }
            
            let deleteAction = UIAction(title: "Delete", image: UIImage(systemName: "trash"), attributes: .destructive) { _ in
                self.deleteURL(item) { _ in }
            }
            
            children.append(contentsOf: [operationItemsMenu, pasteboardOptions])
            children.append(UIMenu(options: .displayInline, children: [deleteAction]))
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
    /// Returns the UIMenu to be used as the (primary) right bar button
    func makeRightBarButton() -> UIMenu {
        let selectAction = UIAction(title: "Select", image: UIImage(systemName: "checkmark.circle")) { _ in
            self.tableView.allowsMultipleSelectionDuringEditing = true
            self.setEditing(true, animated: true)
        }
        
        let selectionMenu = UIMenu(options: .displayInline, children: [selectAction])
        var firstMenuItems = [selectionMenu, makeSortMenu(), makeGoToMenu()]
        
        if let currentPath = currentPath {
            firstMenuItems.append(makeNewItemMenu(forURL: currentPath))
        }
        
        let firstMenu = UIMenu(options: .displayInline, children: firstMenuItems)
        var menuActions: [UIMenuElement] = [firstMenu]
        
        // if we're in the "Favorites" sheet, don't display the Favorites button
        if !isFavouritePathsSheet {
            let seeFavoritesAction = UIAction(title: "Favorites", image: UIImage(systemName: "star.fill")) { _ in
                let newVC = UINavigationController(rootViewController: SubPathsTableViewController.Favorites())
                self.present(newVC, animated: true)
            }
            
            menuActions.append(seeFavoritesAction)
        }
        
        if let currentPath = currentPath {
            let showInfoAction = UIAction(title: "Info", image: .init(systemName: "info.circle")) { _ in
                self.openInfoBottomSheet(path: currentPath)
            }
            
            menuActions.append(showInfoAction)
        }
        
        let settingsAction = UIAction(title: "Settings", image: UIImage(systemName: "gear")) { _ in
            self.present(UINavigationController(rootViewController: SettingsTableViewController(style: .insetGrouped)), animated: true)
        }
        menuActions.append(settingsAction)
        
        let showOrHideHiddenFilesAction = UIAction(
            title: "Display hidden files",
            state: displayHiddenFiles ? .on : .off
        ) { _ in
            self.displayHiddenFiles.toggle()
            self.setRightBarButton()
        }
        
        menuActions.append(showOrHideHiddenFilesAction)
        return UIMenu(children: menuActions)
    }
    
    func setRightBarButton() {
        if self.isEditing {
            let editAction = UIAction {
                self.setEditing(false, animated: true)
            }
            
            self.navigationItem.rightBarButtonItem = UIBarButtonItem(
                systemItem: .done,
                primaryAction: editAction
            )
            
        } else {
            self.navigationItem.rightBarButtonItem = UIBarButtonItem(
                image: .init(systemName: "ellipsis.circle"),
                menu: makeRightBarButton()
            )
        }
    }
    
    override func setEditing(_ editing: Bool, animated: Bool) {
        super.setEditing(editing, animated: animated)
        
        setRightBarButton()
        setLeftBarSelectionButtonItem()
        if editing {
            setupOrUpdateToolbar()
        } else {
            hideToolbar()
            selectedItems = []
        }
    }
    
    func showOrHideDotfiles(animatingDifferences: Bool = false) {
        if !displayHiddenFiles {
            let filtered = unfilteredContents.filter { !$0.lastPathComponent.starts(with: ".") }
            setFilteredContents(filtered, animatingDifferences: animatingDifferences)
        } else {
            setFilteredContents([], animatingDifferences: animatingDifferences)
        }
    }
    
    func setFilteredContents(_ newContents: [URL], animatingDifferences: Bool = false) {
        self.filteredSearchContents = newContents
        if !doDisplaySearchSuggestions {
            self.showPaths(animatingDifferences: animatingDifferences)
        }
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
            let items = self.sortMethod.sorting(URLs: directoryMonitor.url.contents, sortOrder: .userPreferred)
            self.unfilteredContents = items
            
            var snapshot = self.dataSource.snapshot()
            snapshot.deleteAllItems()
            snapshot.appendSections([0])
            
            snapshot.appendItems(SubPathsRowItem.fromPaths(items))
            self.dataSource.apply(snapshot, animatingDifferences: true)
            
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

extension SubPathsTableViewController: UINavigationItemRenameDelegate {
    func navigationItem(_: UINavigationItem, didEndRenamingWith title: String) {
        guard let currentPath = currentPath else {
            return
        }
        
        let newURL = currentPath.deletingLastPathComponent().appendingPathComponent(title)
        do {
            try FileManager.default.moveItem(at: currentPath, to: newURL)
            self.currentPath = newURL
        } catch {
            self.errorAlert(error, title: "Uname to rename \(newURL.lastPathComponent)")
            // renaming automatically changes title
            // so we need to change back the title to the original
            // in case of a failure
            self.title = currentPath.lastPathComponent
        }
    }
    
    func navigationItemShouldBeginRenaming(_: UINavigationItem) -> Bool {
        return currentPath != nil
    }
}

/// Represents an item which could be displayed in SubPathsTableViewController,
/// being either a search suggestion or a path
enum SubPathsRowItem: Hashable {
    static func == (lhs: SubPathsRowItem, rhs: SubPathsRowItem) -> Bool {
        switch (lhs, rhs) {
        case (.path(let firstURL), .path(let secondURL)):
            return firstURL == secondURL
        case (.searchSuggestion(let firstSuggestion), .searchSuggestion(let secondSuggestion)):
            return firstSuggestion == secondSuggestion
        default:
            return false
        }
    }
    
    func hash(into hasher: inout Hasher) {
        switch self {
        case .searchSuggestion(let searchSuggestion):
            hasher.combine(searchSuggestion)
        case .path(let url):
            hasher.combine(url)
        }
    }
    
    case searchSuggestion(SearchSuggestion)
    case path(URL)
    
    /// Return an array of items from an array of URLs
    static func fromPaths(_ paths: [URL]) -> [SubPathsRowItem] {
        return paths.map { url in
            return .path(url)
        }
    }
}
