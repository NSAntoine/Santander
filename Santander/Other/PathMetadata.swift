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
    
    let permissions: Permission
    
    init(fileURL url: URL, resourceValues: Set<URLResourceKey> = resourceValueKeys) {
        let resourceValues = try? url.resourceValues(forKeys: resourceValues)
        self.creationDate = resourceValues?.creationDate
        self.addedToDirectoryDate = resourceValues?.addedToDirectoryDate
        self.lastModifiedDate = resourceValues?.contentModificationDate
        self.lastAccessedDate = resourceValues?.contentAccessDate
        self.contentType = resourceValues?.contentType
        self.permissions = Permission(fileURL: url)
    }
}

/// Represents the permissions of a path in POSIX Style
struct Permission: OptionSet {
    public var rawValue: Int

    /// Grants the permission to execute a file
    static let execute = Permission(rawValue: 1)
    /// Grants the permission to modify a file
    static let write = Permission(rawValue: 2)
    /// Grants the permission to read a file
    static let read = Permission(rawValue: 4)

    init(rawValue: Int) {
        self.rawValue = rawValue
    }
    
    /// Initializes a new Permissions object based of the permissions
    /// of the given file URL
    init(fileURL: URL) {
        var perms: Permission = []
        let path = fileURL.path
        
        if FileManager.default.isReadableFile(atPath: path) {
            perms.insert(.read)
        }
        
        if FileManager.default.isWritableFile(atPath: path) {
            perms.insert(.write)
        }
        
        if FileManager.default.isExecutableFile(atPath: path) {
            perms.insert(.execute)
        }
        
        self = perms
    }
    
    var binaryRepresentation: String {
        var b = String(rawValue, radix: 2)
        while b.count < 3 { b = "0" + b }
        return b
    }

    static func binaryRepresentation(of permissions: [Permission]) -> String {
        return permissions.map { $0.binaryRepresentation }.joined()
    }

    static func octalRepresentation(of permissions: [Permission]) -> Int {
        let binary = binaryRepresentation(of: permissions)
        return Int(binary, radix: 2)!
    }
}
