//
//  Search.swift
//  Santander
//
//  Created by Serena on 25/06/2022
//
	

import UIKit

extension PathContentsTableViewController: UISearchResultsUpdating, UISearchBarDelegate {
    func updateSearchResults(for searchController: UISearchController) {
        updateResults(searchBar: searchController.searchBar)
    }
    
    func cancelSearch() {
        self.filteredSearchContents = []
        self.isSearching = false
        tableView.reloadData()
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
        
        self.isSearching = true
        var results: [URL] = []
        if let currentPath = currentPath, searchBar.selectedScopeButtonIndex == 1 {
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
