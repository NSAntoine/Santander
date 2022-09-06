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
    var displayingSearchSuggestions: Bool = false
    
    /// the Directory Monitor, used to observe changes
    /// if the path is a directory
    var directoryMonitor: DirectoryMonitor?
    
    /// The Audio Player View Controller to display
    var audioPlayerController: AudioPlayerViewController?
    
    /// The label which displays that the user doesn't have permission to view a directory,
    /// or that the directory / group is empty
    /// (if those conditions apply)
    var permissionDeniedLabel: UILabel!
    
    /// Whether or not to display files beginning with a dot in their names
    var displayHiddenFiles: Bool = UserPreferences.displayHiddenFiles {
        didSet {
            showOrHideDotfiles()
            
            UserPreferences.displayHiddenFiles = self.displayHiddenFiles
        }
    }
    
    /// Whether or not the current path contains subpaths that are app UUIDs
    var containsAppUUIDs: Bool?
    
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
    class func favorites() -> SubPathsTableViewController {
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
            self.containsAppUUIDs = currentPath.containsAppUUIDSubpaths
        }
        self.navigationItem.searchController = searchController
#if compiler(>=5.7)
        if #available(iOS 16.0, *), UIDevice.current.isiPad {
            self.navigationItem.style = .browser
            self.navigationItem.renameDelegate = self
        }
#endif
        
        tableView.dragInteractionEnabled = true
        tableView.dropDelegate = self
        tableView.dragDelegate = self
        tableView.dataSource = self.dataSource
        showPaths()
        
        setupPermissionDeniedLabelIfNeeded()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        // The code for setting up the directory monitor should stay in viewDidAppear
        // if used in viewDidLoad, it won't be monitoring if the user goes into a different directory
        // then comes back
        if let currentPath = self.currentPath {
            if directoryMonitor == nil {
                directoryMonitor = DirectoryMonitor(url: currentPath)
                directoryMonitor?.delegate = self
            }
            
            directoryMonitor?.startMonitoring()
            // set the last opened path here
            UserPreferences.lastOpenedPath = currentPath.path
        }
    }
    /// Setup the snapshot to show the paths given
    func showPaths(animatingDifferences: Bool = false) {
        self.displayingSearchSuggestions = false
        var snapshot = dataSource.snapshot()
        snapshot.deleteAllItems()
        snapshot.deleteSections([1, 2])
        
        snapshot.appendSections([0])
        snapshot.appendItems(SubPathsRowItem.fromPaths(contents))
        dataSource.apply(snapshot, animatingDifferences: animatingDifferences)
    }
    
    /// Show the search suggestions
    func switchToSearchSuggestions() {
        displayingSearchSuggestions = true
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
            setLeftBarSelectionButtonItem()
            return
        }
        
        if displayingSearchSuggestions {
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
            tableView.deselectRow(at: indexPath, animated: true)
        }
    }
    
    override func tableView(_ tableView: UITableView, didDeselectRowAt indexPath: IndexPath) {
        guard self.isEditing else {
            return
        }
        
        let selected = contents[indexPath.row]
        selectedItems.removeAll { path in
            path == selected
        }
        
        setupOrUpdateToolbar()
        setLeftBarSelectionButtonItem()
    }
    
    override func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        
        guard !displayingSearchSuggestions else {
            return nil
        }
        
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
            "Library": FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask).first,
            "/ (Root)" : .root
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
            
            alert.addAction(.cancel())
            alert.addAction(goAction)
            alert.preferredAction = goAction
            self.present(alert, animated: true)
        }
        
        menu = menu.appending(otherLocationAction)
        
        return menu
    }
    
    
    func goToFile(path: URL) {
        if path.pathExtension == "zip" {
            DispatchQueue.main.async {
                do {
                    try Compression.shared.unzipFile(path, destination: path.deletingPathExtension(), overwrite: true, password: nil)
                } catch {
                    self.errorAlert(error, title: "Unable to decompress \"\(path.lastPathComponent)\"")
                }
            }
        } else if let preferred = FileEditor.preferred(forURL: path) {
            preferred.display(senderVC: self)
            
            // if it's the audio viewcontroller & the file URL is different than the current property audio controller
            // set the current audioVC property to it
            if let audioVC = preferred.viewController as? AudioPlayerViewController {
                // if music is already playing, then stop it
                self.audioPlayerController?.player.stop()
                // then set the current audio controller to the file tapped
                self.audioPlayerController = audioVC
                self.setupAudioToolbarIfPossible()
            }
            
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
    func goToPath(path: URL, pushingToSplitView: Bool = false) {
        // Make sure we're opening a directory,
        // or the parent directory of the file selected (if searching)
        
        // if we're going to a directory, or a search result,
        // go to the directory path
        if path.isDirectory {
            let parentDirectory = path.deletingLastPathComponent()
            
            // if the parent directory is the current directory or we're in the favourites sheet
            // simply push through the navigation controller
            // rather than traversing through each parent path
            if isFavouritePathsSheet || parentDirectory == self.currentPath {
                let vc = SubPathsTableViewController(path: path, isFavouritePathsSheet: self.isFavouritePathsSheet)
                if pushingToSplitView {
                    self.splitViewController?.setViewController(vc, for: .secondary)
                } else {
                    self.navigationController?.pushViewController(vc, animated: true)
                }
            } else {
                traverseThroughPath(path, pushingToSplitView: pushingToSplitView)
            }
        } else {
            self.goToFile(path: path)
        }
    }
    
    func traverseThroughPath(_ path: URL, pushingToSplitView: Bool) {
        let vcs = path.fullPathComponents().map {
            SubPathsTableViewController(path: $0, isFavouritePathsSheet: self.isFavouritePathsSheet)
        }
        
        if pushingToSplitView {
            let navVC = UINavigationController()
            navVC.setViewControllers(vcs, animated: true)
            self.splitViewController?.setViewController(navVC, for: .secondary)
        } else {
            self.navigationController?.setViewControllers(vcs, animated: true)
        }
    }
    
    func sortContents() {
        self.unfilteredContents = sortMethod.sorting(URLs: unfilteredContents, sortOrder: .userPreferred)
        showOrHideDotfiles(animatingDifferences: true)
    }
    
    /// Opens the information bottom sheet for a specified path
    func openInfoBottomSheet(path: URL) {
        if let app = path.applicationItem {
            // if we can get the app info too,
            // present an action sheet to choose between either
            let actionSheet = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
            let pathInfoAction = UIAlertAction(title: "Path Info", style: .default) { _ in
                let navController = UINavigationController(
                    rootViewController: PathInformationTableViewController(style: .insetGrouped, path: path)
                )
                
                if #available(iOS 15.0, *) {
                    navController.sheetPresentationController?.detents = [.medium(), .large()]
                }
                
                self.present(navController, animated: true)
            }
            
            let appInfoAction = UIAlertAction(title: "App Info", style: .default) { _ in
                let navController = UINavigationController(
                    rootViewController: AppInfoViewController(style: .insetGrouped, app: app, subPathsSender: self)
                )
                
                self.present(navController, animated: true)
            }
            
            actionSheet.addAction(appInfoAction)
            actionSheet.addAction(pathInfoAction)
            actionSheet.addAction(.init(title: "Cancel", style: .cancel))
            
            actionSheet.popoverPresentationController?.sourceView = view
            let bounds = view.bounds
            actionSheet.popoverPresentationController?.sourceRect = CGRect(x: bounds.midX, y: bounds.midY, width: 0, height: 0)
            self.present(actionSheet, animated: true)
        } else {
            let navController = UINavigationController(
                rootViewController: PathInformationTableViewController(style: .insetGrouped, path: path)
            )
            
            if #available(iOS 15.0, *) {
                navController.sheetPresentationController?.detents = [.medium(), .large()]
            }
            
            self.present(navController, animated: true)
        }
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
        defer {
            cell.contentConfiguration = cellConf
        }
        
        // if we're displaying an app, whether it's a .app
        // or an app in the containers URL
        // display the properties of the app instead

        // for performance, we check first for if the current path contains app UUIDs (if the pathExt isn't .app)
        // otherwise, if currentPath is nil, check for if the parent dir of the path contains app UUIDs
        // performance is worse if we *always* do the first,
        // but `containsAppUUIDs` isn't nil as long as `currentPath` isn't nil.
        if fsItem.pathExtension == "app" || (containsAppUUIDs ?? fsItem.deletingLastPathComponent().containsAppUUIDSubpaths),
           let app = fsItem.applicationItem {
            cellConf.text = app.localizedName()
            cellConf.image = ApplicationsManager.shared.icon(forApplication: app)
            cellConf.secondaryText = fsItem.lastPathComponent
            cell.accessoryType = .disclosureIndicator
            cellConf.textProperties.color = tableView.tintColor ?? .systemBlue
            return cell
        }
        
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
        
        return cell
    }
    
    override func tableView(_ tableView: UITableView, contextMenuConfigurationForRowAt indexPath: IndexPath, point: CGPoint) -> UIContextMenuConfiguration? {
        
        if displayingSearchSuggestions {
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
            vc.view.backgroundColor = .systemBackground
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
                self.presentActivityVC(forItems: [item])
            }
            
            let renameAction = UIAction(title: "Rename", image: UIImage(systemName: "rectangle.and.pencil.and.ellipsis")) { _ in
                let alert = UIAlertController(title: "Rename", message: nil, preferredStyle: .alert)
                
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
                
                alert.addAction(.cancel())
                alert.addAction(renameAction)
                self.present(alert, animated: true)
            }
            
            var children: [UIMenuElement] = [informationAction, renameAction, shareAction]
            
            let compressOrDecompressAction: UIAction
            if item.pathExtension != "zip" {
                compressOrDecompressAction = UIAction(title: "Compress", image: UIImage(systemName: "archivebox")) { _ in
                    let zipFilePath = item.deletingPathExtension().appendingPathExtension("zip")
                    do {
                        try Compression.shared.zipFiles(paths: [item], zipFilePath: zipFilePath, password: nil, progress: nil)
                    } catch {
                        self.errorAlert(error, title: "Unable to compress \"\(item.lastPathComponent)\"")
                    }
                }
            } else {
                compressOrDecompressAction = UIAction(title: "Decompress", image: UIImage(systemName: "archivebox")) { _ in
                    let destination = item.deletingPathExtension()
                    do {
                        try Compression.shared.unzipFile(item, destination: destination, overwrite: true, password: nil)
                    } catch {
                        self.errorAlert(error, title: "Unable to decompress \"\(item.lastPathComponent)\"")
                    }
                }
            }
            
            children.append(compressOrDecompressAction)
            
            // "Open App" option for apps
            if let app = item.applicationItem {
                let openAction = UIAction(title: "Open App") { _ in
                    do {
                        try ApplicationsManager.shared.openApp(app)
                    } catch {
                        self.errorAlert(error, title: "Unable to open app")
                    }
                }
                children.append(openAction)
            }
            
            if !item.isDirectory {
                let allEditors = FileEditor.allEditors(forURL: item)
                var actions = allEditors.map { editor in
                    UIAction(title: editor.type.description) { _ in
                        editor.display(senderVC: self)
                    }
                }
                
                // always have a QuickLook action
                let qlAction = UIAction(title: "QuickLook") { _ in
                    self.openQuickLookPreview(forURL: item)
                }
                
                actions.append(qlAction)
                
                //TODO: - For insanely large files, this results in a crash, find a way around this.
                // maybe use a UIAlertController as an actionSheet?
                children.append(UIMenu(title: "Open in..", children: actions))
            }
            
            if UIDevice.current.isiPad {
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
                let newVC = UINavigationController(rootViewController: SubPathsTableViewController.favorites())
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
            hideToolbarItems()
            selectedItems = []
        }
    }
    
    /// Shows or hides dotfiles,
    /// this method is the primary way of reloading the view
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
        if !displayingSearchSuggestions {
            self.showPaths(animatingDifferences: animatingDifferences)
        }
    }
    
    func setupPermissionDeniedLabelIfNeeded() {
        guard let currentPath = currentPath, !currentPath.isReadable else {
            return
        }
        
        permissionDeniedLabel = UILabel()
        permissionDeniedLabel.text = "Don't have permission to read directory."
        
        permissionDeniedLabel.font = .systemFont(ofSize: 20, weight: .medium)
        permissionDeniedLabel.textColor = .systemGray
        permissionDeniedLabel.textAlignment = .center
        
        self.view.addSubview(permissionDeniedLabel)
        permissionDeniedLabel.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            permissionDeniedLabel.centerXAnchor.constraint(equalTo: self.view.centerXAnchor),
            permissionDeniedLabel.centerYAnchor.constraint(equalTo: self.view.centerYAnchor)
        ])
    }
}

extension SubPathsTableViewController: DirectoryMonitorDelegate {
    func directoryMonitorDidObserveChange(directoryMonitor: DirectoryMonitor) {
        DispatchQueue.main.async {
            let items = self.sortMethod.sorting(URLs: directoryMonitor.url.contents, sortOrder: .userPreferred)
            self.unfilteredContents = items
            self.showOrHideDotfiles(animatingDifferences: true)
            
            if self.isSearching, let searchBar = self.navigationItem.searchController?.searchBar {
                // If we're searching,
                // update the search bar
                self.updateResults(searchBar: searchBar)
            }
        }
    }
}
#if compiler(>=5.7)
extension SubPathsTableViewController: UINavigationItemRenameDelegate {
    func navigationItem(_: UINavigationItem, didEndRenamingWith title: String) {
        guard let currentPath = currentPath else {
            return
        }
        
        let newURL = currentPath.deletingLastPathComponent().appendingPathComponent(title)
        
        // new name is the exact same, don't continue renaming
        guard currentPath != newURL else {
            return
        }
        
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
#endif

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

