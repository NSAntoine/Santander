//
//  Permissions.swift
//  Santander
//
//  Created by Serena on 05/08/2022.
//

import Foundation

/// Represents the permissions of a path in POSIX Style
struct Permission: OptionSet, CustomStringConvertible, Equatable {
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
    
    /// Initializes a new instant by checking the `st_mode` of the stat buffer
    /// and matching the constants given.
    /// see `ownerPermsConstants`, `groupPermsConstants`, and `otherUsersPermsConstants`
    init(buffer: stat, constants: [UInt16: Permission]) {
        self = constants.filter { (constant, _) in
            return (buffer.st_mode & constant) != 0
        }
        
        .map(\.value)
        .reducingToSingleOptionSet()
    }
    
    var binaryRepresentation: String {
        var b = String(rawValue, radix: 2)
        while b.count < 3 { b = "0" + b }
        return b
    }
    
    var description: String {
        return "Readable: \(contains(.read)), Writable: \(contains(.write)), Executable: \(contains(.execute))"
    }
    
    static func binaryRepresentation(of permissions: [Permission]) -> String {
        return permissions.map { $0.binaryRepresentation }.joined()
    }

    static func octalRepresentation(of permissions: [Permission]) -> Int {
        let binary = binaryRepresentation(of: permissions)
        return Int(binary, radix: 2)!
    }
    
    /// A dictionary representing the constants which could be checked
    /// for the owner permissions of a path
    static let ownerPermsConstants: [UInt16: Permission] = [
        S_IRUSR: .read,
        S_IWUSR: .write,
        S_IXUSR: .execute
    ]
    
    /// A dictionary representing the constants which could be checked
    /// for the group permissions of a path
    static let groupPermsConstants: [UInt16: Permission] = [
        S_IRGRP: .read,
        S_IWGRP: .write,
        S_IXGRP: .execute
    ]
    
    /// A dictionary representing the constants which could be checked
    /// for the permissions of other users of a path
    static let otherUsersPermsConstants: [UInt16: Permission] = [
        S_IROTH: .read,
        S_IWOTH: .write,
        S_IXOTH: .execute
    ]
    
}

/// Represents the permissions of a path,
/// including permissions for owner, group, and other users
struct PathPermissions: Equatable {
    let fileURL: URL
    
    var ownerPermissions: Permission
    var groupPermissions: Permission
    var otherUsersPermissions: Permission
    
    var ownerName: String?
    var groupOwnerName: String?
    
    init?(fileURL: URL) {
        var buffer = stat()
        guard lstat(fileURL.path, &buffer) == 0 else {
            return nil
        }
        
        self.ownerPermissions = Permission(buffer: buffer, constants: Permission.ownerPermsConstants)
        self.groupPermissions = Permission(buffer: buffer, constants: Permission.groupPermsConstants)
        self.otherUsersPermissions = Permission(buffer: buffer, constants: Permission.otherUsersPermsConstants)
        
        let attrs = try? FileManager.default.attributesOfItem(atPath: fileURL.path)
        self.ownerName = attrs?[.ownerAccountName] as? String
        self.groupOwnerName = attrs?[.groupOwnerAccountName] as? String
        
        self.fileURL = fileURL
    }
    
    init(fileURL: URL, ownerPermissions: Permission, groupPermissions: Permission, otherUsersPermissions: Permission, ownerName: String? = nil, groupOwnerName: String? = nil) {
        self.fileURL = fileURL
        self.ownerPermissions = ownerPermissions
        self.groupPermissions = groupPermissions
        self.otherUsersPermissions = otherUsersPermissions
        self.ownerName = ownerName
        self.groupOwnerName = groupOwnerName
    }
    
    func apply() throws {
        try fileURL.setPermissions(forOwner: ownerPermissions, group: groupPermissions, others: otherUsersPermissions)
    }
}
