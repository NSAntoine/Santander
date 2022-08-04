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
        showPaths()
    }
    
    func searchBar(_ searchBar: UISearchBar, selectedScopeButtonIndexDidChange selectedScope: Int) {
        updateResults(searchBar: searchBar)
    }
    
    func updateResults(searchBar: UISearchBar) {
        let searchText = searchBar.searchTextField.text ?? ""
        
        // Make sure that we have search conditions or that the search text isn't empty
        guard !(searchText.isEmpty && searchBar.searchTextField.tokens.isEmpty) else {
            self.isSearching = false
            setFilteredContents([])
            return
        }
        
        self.isSearching = true
        var results: [URL] = []
        if let currentPath = currentPath, searchBar.selectedScopeButtonIndex == 1 {
            results = FileManager.default.enumerator(at: currentPath, includingPropertiesForKeys: [])?.allObjects.compactMap { $0 as? URL } ?? []
        } else {
            results = unfilteredContents
        }
        
        // Get the conditions that were set (if any)
        let conditions = searchBar.searchTextField.tokens.compactMap { token in
            token.representedObject as? ((URL) -> Bool)
        }
        
        self.doDisplaySearchSuggestions = false
        let newFiltered = results.filter { url in
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
        
        setFilteredContents(newFiltered)
    }
    
    func presentSearchController(_ searchController: UISearchController) {
        switchToSearchSuggestions()
    }
}


/// Represents a search suggestion to be displayed in the UI,
/// with a given condition for the search results.
@available(iOS 14.0, *)
struct SearchSuggestion: Hashable {
    /// The name to be displayed in the search suggestion
    var name: String
    
    /// The image to be displayed in the search suggestion
    let image: UIImage?
    
    /// The condition to which the given URL should abide to
    var condition: ((URL) -> Bool)
    
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
    
    static func == (lhs: SearchSuggestion, rhs: SearchSuggestion) -> Bool {
        return lhs.name == rhs.name && lhs.image == rhs.image
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(self.name)
        hasher.combine(self.image)
    }
}
