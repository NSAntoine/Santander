//
//  Search.swift
//  Santander
//
//  Created by Serena on 25/06/2022
//
	

import UIKit
import UniformTypeIdentifiers

extension SubPathsTableViewController: UISearchResultsUpdating, UISearchControllerDelegate, UISearchBarDelegate {
    
    func updateSearchResults(for searchController: UISearchController) {
        updateResults(searchBar: searchController.searchBar)
    }
    
    func searchBarCancelButtonClicked(_ searchBar: UISearchBar) {
        DispatchQueue.main.async { [self] in
            searchItem?.cancel()
            isSearching = false
            displayingSearchSuggestions = false
            reloadTableData()
            
            setupPermissionDeniedLabelIfNeeded()
        }
    }
    
    func searchBar(_ searchBar: UISearchBar, selectedScopeButtonIndexDidChange selectedScope: Int) {
        updateResults(searchBar: searchBar)
    }
    
    @objc
    func updateResults(searchBar: UISearchBar) {
        let selectedScope = searchBar.selectedScopeButtonIndex
        let query = SearchQuery(searchBar: searchBar)
        
        self.searchItem?.cancel()
        isSearching = true
        guard !query.isEmpty else { return }
        displayingSearchSuggestions = false
        
        let newWorkItem = DispatchWorkItem(qos: .userInteractive) { [self] in
            
            switch selectedScope {
            case 0: // searching in current directory
                let filtered = unfilteredContents.filter { url in
                    return query.matches(url: url)
                }
                
                DispatchQueue.main.async {
                    self.setFilteredContents(filtered)
                }
                
            case 1: // searching in subdirectories of the directory
                var snapshot = Snapshot()
                snapshot.appendSections([0])
                __enumeratePaths(unfilteredContents, withQuery: query, doBreak: { !isSearching }) { [self] path in
                    DispatchQueue.main.async {
                        let row: SubPathsRowItem = .path(path)
                        if !snapshot.itemIdentifiers.contains(row) {
                            snapshot.appendItems([row])
                            self.dataSource.apply(snapshot, animatingDifferences: false)
                        }
                    }
                }
            default: // should never get here
                break
            }
        }
        
        self.searchItem = newWorkItem
        DispatchQueue.global(qos: .userInteractive).asyncAfter(
            deadline: .now().advanced(by: .milliseconds(2)),
            execute: newWorkItem
        )
    }
    
    func presentSearchController(_ searchController: UISearchController) {
        if isEditing {
            setEditing(false, animated: true)
        }
        
        switchToSearchSuggestions()
        permissionDeniedLabel?.removeFromSuperview()
    }
    
    private func __enumeratePaths(_ paths: [URL], withQuery query: SearchQuery, doBreak: () -> Bool, handler: (URL) -> ()) {
        for path in paths {
            if doBreak() { break }
            
            if query.matches(url: path) {
                handler(path)
            }
            
            if path.isDirectory {
                __enumeratePaths(path.contents, withQuery: query, doBreak: doBreak, handler: handler)
            }
        }
    }
    
    fileprivate struct SearchQuery {
        let searchText: String
        let conditions: [SearchSuggestion.Condition]
        let isSearchTextEmpty: Bool
        
        // whether or not the given URL should be displayed in search results
        // according to this query
        func matches(url: URL) -> Bool {
            let allConditionsSatisfied = conditions.allSatisfy { handler in
                handler(url)
            }
            
            if isSearchTextEmpty {
                return allConditionsSatisfied
            }
            
            return url.lastPathComponent.localizedCaseInsensitiveContains(searchText) && allConditionsSatisfied
        }
        
        var isEmpty: Bool {
            return isSearchTextEmpty && conditions.isEmpty
        }
        
        init(searchText: String, conditions: [SearchSuggestion.Condition]) {
            self.searchText = searchText
            self.conditions = conditions
            
            self.isSearchTextEmpty = searchText.isEmpty
        }
        
        init(searchBar: UISearchBar) {
            self.searchText = searchBar.text ?? ""
            self.conditions = searchBar.searchTextField.tokens.compactMap { $0.representedObject as? SearchSuggestion.Condition }
            
            self.isSearchTextEmpty = searchText.isEmpty
        }
    }
}


/// Represents a search suggestion to be displayed in the UI,
/// with a given condition for the search results.
@available(iOS 14.0, *)
struct SearchSuggestion: Hashable {
    
    typealias Condition = (URL) -> Bool
    
    /// The name to be displayed in the search suggestion
    var name: String
    
    /// The image to be displayed in the search suggestion
    let image: UIImage?
    
    /// The condition to which the given URL should abide to
    var condition: Condition
    
    var searchToken: UISearchToken {
        let token = UISearchToken(icon: image, text: name)
        token.representedObject = condition
        return token
    }
    
    /// The search suggestion to display in the UI, based on the indexPath given
    static func displaySearchSuggestions(for indexPath: IndexPath, typesToCheck: [UTType]? = nil) -> SearchSuggestion {
        switch (indexPath.section, indexPath.row) {
        case (0, 0):
            return SearchSuggestion(name: "Type", image: UIImage(systemName: "menucard")) { url in
                guard let typesToCheck = typesToCheck, let urlType = url.contentType else {
                    return false
                }
                
                let isSubtype = typesToCheck.contains { type in
                    urlType.isSubtype(of: type)
                }
                
                return typesToCheck.contains(urlType) || isSubtype
            }
            
        case (1, 0):
            return SearchSuggestion(name: "File", image: UIImage(systemName: "doc")) { url in
                return !url.isDirectory
            }
        case (1, 1):
            return SearchSuggestion(name: "Directory", image: UIImage(systemName: "folder")) { url in
                return url.isDirectory
            }
        case (1, 2):
            return SearchSuggestion(name: "Symbolic Link", image: UIImage(systemName: "link")) { url in
                return url.isSymlink
            }
        case (2, 0):
            return SearchSuggestion(name: "Executable", image: UIImage(systemName: "terminal")) { url in
                return !url.isDirectory && FileManager.default.isExecutableFile(atPath: url.path)
            }
        case (2, 1):
            return SearchSuggestion(name: "Readable", image: UIImage(systemName: "book")) { url in
                return url.isReadable
            }
        case (2, 2):
            return SearchSuggestion(name: "Writable", image: UIImage(systemName: "pencil")) { url in
                return FileManager.default.isWritableFile(atPath: url.path)
            }
        default: fatalError()
        }
    }
    
    /// The index paths of the search suggestions
    static let searchSuggestionSectionAndRows = [
        IndexPath(row: 0, section: 0),
        IndexPath(row: 0, section: 1), IndexPath(row: 1, section: 1), IndexPath(row: 2, section: 1),
        IndexPath(row: 0, section: 2), IndexPath(row: 1, section: 2), IndexPath(row: 2, section: 2)
    ]
    
    static func == (lhs: SearchSuggestion, rhs: SearchSuggestion) -> Bool {
        return lhs.name == rhs.name && lhs.image == rhs.image
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(self.name)
        hasher.combine(self.image)
    }
}
