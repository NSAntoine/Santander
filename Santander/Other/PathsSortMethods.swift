//
//  PathsSortMethods.swift
//  Santander
//
//  Created by Serena on 24/06/2022
//
	

import Foundation

/// The ways to sort given subpaths
enum PathsSortMethods: String, CaseIterable, CustomStringConvertible {
    case alphabetically
    case size
    case type
    case dateCreated
    case dateModified
    case dateAccessed
    
    static var userPrefered: PathsSortMethods? {
        if let string = UserDefaults.standard.string(forKey: "SubPathsSortMode"), let sortMode = PathsSortMethods(rawValue: string) {
            return sortMode
        }
        
        return nil
    }
    
    var description: String {
        switch self {
        case .alphabetically:
            return "Alphabetical order"
        case .size:
            return "Size"
        case .type:
            return "Type"
        case .dateCreated:
            return "Date created"
        case .dateModified:
            return "Date modified"
        case .dateAccessed:
            return "Date accessed"
        }
    }
    
    /// Sorts an array of URLs with the current sort method
    func sorting(URLs urls: [URL], sortOrder: SortOrder) -> [URL] {
        return urls.sorted { (firstURL: URL, secondURL: URL) in
            let ascending: Bool
            switch self {
            case .alphabetically:
                ascending = firstURL.lastPathComponent < secondURL.lastPathComponent
            case .size:
                ascending = firstURL.size > secondURL.size
            case .type:
                return firstURL.contentType == secondURL.contentType
            case .dateCreated:
                ascending = firstURL.creationDate > secondURL.creationDate
            case .dateModified:
                ascending =  firstURL.lastModifiedDate > secondURL.lastModifiedDate
            case .dateAccessed:
                ascending = firstURL.lastAccessedDate > secondURL.lastAccessedDate
            }
            
            if sortOrder == .descending {
                return !ascending
            }
            
            return ascending
        }
    }
}

enum SortOrder: String, CaseIterable, CustomStringConvertible {
    case ascending, descending
    
    init(rawValue: String) {
        switch rawValue.lowercased() {
        case "ascending":
            self = .ascending
        case "descending":
            self = .descending
        default:
            self = .ascending // Default to ascending
        }
    }
    
    static var userPreferred: SortOrder {
        guard let rawValue = UserDefaults.standard.string(forKey: "SortOrder") else {
            return .ascending
        }
        
        return self.init(rawValue: rawValue)
    }
    
    var description: String {
        switch self {
        case .ascending:
            return "Ascending"
        case .descending:
            return "Descending"
        }
    }
    
    /// The SF Symbol name of the sort order
    var imageSymbolName: String {
        switch self {
        case .ascending:
            return "chevron.up"
        case .descending:
            return "chevron.down"
        }
    }
    
    func toggling() -> SortOrder {
        switch self {
        case .ascending:
            return .descending
        case .descending:
            return .ascending
        }
    }
}
