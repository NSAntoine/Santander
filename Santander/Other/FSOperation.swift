//
//  FSOperation.swift
//  Santander
//
//  Created by Serena on 15/09/2022
//


import Foundation

// You may ask, hey, why is this an enum and not a struct / class with several functions?
// well:
// 1) this allows for just one unified function, rather than many
// 2) this allows to redirect to a root helper

/// Lists operations that can be done to the FileSystem
enum FSOperation: Codable {
    case removeItem
    case createFile
    case createDirectory
    
    case moveItem(resultPath: URL)
    case copyItem(resultPath: URL)
    
    case symlink(destination: URL)
    
    case setOwner(newOwner: String)
    case setGroup(newGroup: String)
    
    case setPermissions(newOctalPermissions: Int)
    
    static private let fm = FileManager.default
    
    static func perform(_ operation: FSOperation, url: URL) throws {
        switch operation {
        case .removeItem:
            try fm.removeItem(at: url)
        case .createFile:
            // fopen being nil: failed to make file
            // mode a: create if the path doesn't exist
            guard let file = fopen((url as NSURL).fileSystemRepresentation, "a") else {
                throw _Errors.errnoError
            }
            
            fclose(file) // close when we're done
        case .createDirectory:
            try fm.createDirectory(at: url, withIntermediateDirectories: true)
        case .moveItem(let resultPath):
            try fm.moveItem(at: url, to: resultPath)
        case .copyItem(let resultPath):
            try fm.copyItem(at: url, to: resultPath)
        case .symlink(let destination):
            try fm.createSymbolicLink(at: destination, withDestinationURL: url)
        case .setGroup(let newGroup):
            try fm.setAttributes([.groupOwnerAccountName: newGroup], ofItemAtPath: url.path)
        case .setOwner(let newOwner):
            try fm.setAttributes([.ownerAccountName: newOwner], ofItemAtPath: url.path)
        case .setPermissions(let newOctalPermissions):
            try fm.setAttributes([.posixPermissions: newOctalPermissions], ofItemAtPath: url.path)
        }
    }
    
    private enum _Errors: Error, LocalizedError {
        case errnoError
        case otherError(description: String)
        
        var errorDescription: String? {
            switch self {
            case .errnoError:
                return String(cString: strerror(errno))
            case .otherError(let description):
                return description
            }
        }
    }
}
