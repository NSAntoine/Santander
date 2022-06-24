//
//  Extensions.swift
//  Santander
//
//  Created by Serena on 21/06/2022
//

import UIKit
import UniformTypeIdentifiers

extension URL {
    
    func regularFileAllocatedSize() throws -> UInt64 {
        let resourceValues = try self.resourceValues(forKeys: allocatedSizeResourceKeys)
        
        // We only look at regular files.
        guard resourceValues.isRegularFile ?? false else {
            return 0
        }
        
        return UInt64(resourceValues.totalFileAllocatedSize ?? resourceValues.fileAllocatedSize ?? 0)
    }
    
    var contents: [URL] {
        let _contents = try? FileManager.default.contentsOfDirectory(at: self, includingPropertiesForKeys: [])
        return _contents ?? []
    }
    
    var isDirectory: Bool {
        // Resolve symlinks
        let resolved = (try? FileManager.default.destinationOfSymbolicLink(atPath: self.path)) ?? self.path
        let newURL = URL(fileURLWithPath: resolved)
        // Check for if path is a directory
        return (try? newURL.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false
    }
    
    var creationDate: Date? {
        try? resourceValues(forKeys: [.creationDateKey]).creationDate
    }
    
    var lastModifiedDate: Date? {
        try? resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate
    }
    
    var lastAccessedDate: Date? {
        try? resourceValues(forKeys: [.contentAccessDateKey]).contentAccessDate
    }
    
    var size: Int? {
        if self.isDirectory {
            return try? Int(FileManager.default.allocatedSizeOfDirectory(at: self))
        }
        
        return try? resourceValues(forKeys: [.fileSizeKey]).fileSize
    }
    
    var contentType: UTType? {
        return try? resourceValues(forKeys: [.contentTypeKey]).contentType
    }
    
    /// Display name of the URL path
    var displayName: String {
        return FileManager.default.displayName(atPath: self.path)
    }
    
    var realPath: String? {
        return try? FileManager.default.destinationOfSymbolicLink(atPath: self.path)
    }
}

extension UIViewController {
    func errorAlert(_ errorDescription: String, title: String) {
        let alert = UIAlertController(title: title, message: "Error occured: \(errorDescription)", preferredStyle: .alert)
        alert.addAction(.init(title: "OK", style: .cancel))
        self.present(alert, animated: true)
    }
    
    func errorAlert(_ error: Error, title: String) {
        self.errorAlert(error.localizedDescription, title: title)
    }
}

extension UIMenu {
    func appending(_ element: UIMenuElement) -> UIMenu {
        var children = self.children
        children.append(element)
        return self.replacingChildren(children)
    }
}

extension FileManager {
    
    /// Calculate the allocated size of a directory and all its contents on the volume.
    ///
    /// As there's no simple way to get this information from the file system the method
    /// has to crawl the entire hierarchy, accumulating the overall sum on the way.
    /// The resulting value is roughly equivalent with the amount of bytes
    /// that would become available on the volume if the directory would be deleted.
    ///
    /// - note: There are a couple of oddities that are not taken into account (like symbolic links, meta data of
    /// directories, hard links, ...).
    func allocatedSizeOfDirectory(at directoryURL: URL) throws -> UInt64 {
        
        // The error handler simply stores the error and stops traversal
        var enumeratorError: Error? = nil
        func errorHandler(_: URL, error: Error) -> Bool {
            enumeratorError = error
            return false
        }
        
        // We have to enumerate all directory contents, including subdirectories.
        let enumerator = self.enumerator(at: directoryURL,
                                         includingPropertiesForKeys: Array(allocatedSizeResourceKeys),
                                         options: [],
                                         errorHandler: errorHandler)!
        
        // We'll sum up content size here:
        var accumulatedSize: UInt64 = 0
        
        // Perform the traversal.
        for item in enumerator {
            
            // Bail out on errors from the errorHandler.
            if enumeratorError != nil { break }
            
            // Add up individual file sizes.
            let contentItemURL = item as! URL
            accumulatedSize += try contentItemURL.regularFileAllocatedSize()
        }
        
        // Rethrow errors from errorHandler.
        if let error = enumeratorError { throw error }
        
        return accumulatedSize
    }
}


fileprivate let allocatedSizeResourceKeys: Set<URLResourceKey> = [
    .isRegularFileKey,
    .fileAllocatedSizeKey,
    .totalFileAllocatedSizeKey,
]
