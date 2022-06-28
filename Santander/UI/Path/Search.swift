//
//  Search.swift
//  Santander
//
//  Created by Serena on 25/06/2022
//
	

import UIKit

extension PathContentsTableViewController: UISearchResultsUpdating, UISearchControllerDelegate, UISearchBarDelegate {
    
    func updateSearchResults(for searchController: UISearchController) {
        updateResults(searchBar: searchController.searchBar)
    }
    
    func cancelSearch(displaySuggestions: Bool = false) {
        self.filteredSearchContents = []
        self.isSearching = false
        self.doDisplaySearchSuggestions = displaySuggestions
        tableView.reloadData()
    }
    
    func searchBarCancelButtonClicked(_ searchBar: UISearchBar) {
        cancelSearch()
    }
    
    func searchBar(_ searchBar: UISearchBar, selectedScopeButtonIndexDidChange selectedScope: Int) {
        updateResults(searchBar: searchBar)
    }
    
    func updateResults(searchBar: UISearchBar) {
        let searchText = searchBar.searchTextField.text ?? ""
        if searchBar.searchTextField.tokens.isEmpty {
            guard !searchText.isEmpty else {
                return
            }
        }
        
        self.isSearching = true
        var results: [URL] = []
        if let currentPath = currentPath, searchBar.selectedScopeButtonIndex == 1 {
            results = FileManager.default.enumerator(at: currentPath, includingPropertiesForKeys: [])?.allObjects.compactMap { $0 as? URL } ?? []
        } else {
            results = unfilteredContents
        }
        
        
        let conditions = searchBar.searchTextField.tokens.compactMap { token in
            token.representedObject as? ((URL) -> Bool)
        }
        
        self.filteredSearchContents = results.filter { url in
            let allConditionsMet = conditions.map { condition in
                condition(url)
            }.allSatisfy { isCondtionTrue in
                return isCondtionTrue
            }
            
            if !searchText.isEmpty {
                return allConditionsMet && url.lastPathComponent.localizedCaseInsensitiveContains(searchText)
            }
            
            return allConditionsMet
        }
        
        self.doDisplaySearchSuggestions = false
        tableView.reloadData()
    }
    
    func presentSearchController(_ searchController: UISearchController) {
        self.doDisplaySearchSuggestions = true
        tableView.reloadData()
    }
}

struct SearchSuggestion {
    let name: String
    let image: UIImage?
    var condition: ((URL) -> Bool)
    
    var searchToken: UISearchToken {
        let token = UISearchToken(icon: image, text: name)
        token.representedObject = condition
        return token
    }
    
    /// The search suggestion to display in the UI, based on the indexPath given
    static func displaySearchSuggestions(for indexPath: IndexPath) -> SearchSuggestion {
        switch (indexPath.section, indexPath.row) {
        case (0, 0):
            return SearchSuggestion(name: "File", image: UIImage(systemName: "doc")) { url in
                return !url.isDirectory
            }
        case (0, 1):
            return SearchSuggestion(name: "Directory", image: UIImage(systemName: "folder")) { url in
                return url.isDirectory
            }
        case (0, 2):
            return SearchSuggestion(name: "Symbolic Link", image: UIImage(systemName: "link")) { url in
                return url.isSymlink
            }
        case (1, 0):
            return SearchSuggestion(name: "Executable", image: UIImage(systemName: "terminal")) { url in
                return !url.isDirectory && FileManager.default.isExecutableFile(atPath: url.path)
            }
        case (1, 1):
            return SearchSuggestion(name: "Readable", image: UIImage(systemName: "book")) { url in
                return FileManager.default.isReadableFile(atPath: url.path)
            }
        case (1, 2):
            return SearchSuggestion(name: "Writable", image: UIImage(systemName: "pencil")) { url in
                return FileManager.default.isWritableFile(atPath: url.path)
            }
        default: fatalError()
        }
    }
}
