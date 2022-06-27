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
        
        // Eventually, I want to make it so that the user can choose between if they want to search for the file name
        // and for the path
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
}
