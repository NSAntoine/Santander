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
    func sorting(URLs urls: [URL]) -> [URL] {
        return urls.sorted { firstURL, secondURL in
            switch self {
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
    }
}
