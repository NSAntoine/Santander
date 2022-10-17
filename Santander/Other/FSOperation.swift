//
//  FSOperation.swift
//  Santander
//
//  Created by Serena on 15/09/2022
//


import Foundation
import AssetCatalogWrapper
import UniformTypeIdentifiers

// You may ask, hey, why is this an enum and not a struct / class with several functions?
// well:
// 1) this allows for just one unified function, rather than many
// 2) this allows to redirect to a root helper

/// Lists operations that can be done to the FileSystem
public enum FSOperation: Codable {
    case removeItem
    case createFile
    case createDirectory
    
    case moveItem(resultPath: URL)
    case copyItem(resultPath: URL)
    case symlink(destination: URL)
    
    case setOwner(newOwner: String)
    case setGroup(newGroup: String)
    
    case setPermissions(newOctalPermissions: Int)
    
    case writeData(data: Data)
    case extractCatalog([CodableRendition])
    
    static private let fm = FileManager.default
    
    public static func perform(_ operation: FSOperation, url: URL) throws {
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
        case .writeData(let data):
            try data.write(to: url)
        case .extractCatalog(let rends):
            var failedItems: [String: String] = [:]
            for rend in rends {
                let newURL = url.appendingPathComponent(rend.renditionName)
                if let data = rend.itemData {
                    do {
                        try FSOperation.perform(.writeData(data: data), url: newURL)
                    } catch {
                        failedItems[rend.renditionName] = "Unable to write item data to file: \(error.localizedDescription)"
                    }
                }
                
                if !failedItems.isEmpty {
                    var message: String = ""
                    for (item, error) in failedItems {
                        message.append("\(item): \(error)")
                    }
                    
                    throw _Errors.otherError(description: message.trimmingCharacters(in: .whitespacesAndNewlines))
                }
            }
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
