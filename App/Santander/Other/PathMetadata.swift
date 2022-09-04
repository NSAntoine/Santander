//
//  PathMetadata.swift
//  Santander
//
//  Created by Serena on 04/08/2022.
//

import Foundation
import UniformTypeIdentifiers

/// Describes the information about a given path
struct PathMetadata {
    
    /// The resource values to fetch
    static let resourceValueKeys: Set<URLResourceKey> = [
        .creationDateKey, .contentAccessDateKey, .addedToDirectoryDateKey, .contentModificationDateKey,
        .contentTypeKey
    ]
    
    /// The date the path was created
    let creationDate: Date?
    
    /// The date the path was added to it's parent directory
    let addedToDirectoryDate: Date?
    
    /// The date this path was last modified
    let lastModifiedDate: Date?
    
    /// The date this path was last accessed
    let lastAccessedDate: Date?
    
    /// The type of the path
    let contentType: UTType?
    
    /// The applied permissions of the path
    var permissions: PathPermissions?
    
    init(fileURL url: URL, resourceValues: Set<URLResourceKey> = resourceValueKeys) {
        let resourceValues = try? url.resourceValues(forKeys: resourceValues)
        self.creationDate = resourceValues?.creationDate
        self.addedToDirectoryDate = resourceValues?.addedToDirectoryDate
        self.lastModifiedDate = resourceValues?.contentModificationDate
        self.lastAccessedDate = resourceValues?.contentAccessDate
        self.contentType = resourceValues?.contentType
        self.permissions = PathPermissions(fileURL: url)
    }
}
