//
//  SortingWays.swift
//  Santander
//
//  Created by Serena on 24/06/2022
//
	

import Foundation

/// The ways to sort the
enum SortingWays: CaseIterable, CustomStringConvertible {
    case alphabetically
    case size
    case type
    case dateCreated
    case dateModified
    case dateAccessed
    
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
}
