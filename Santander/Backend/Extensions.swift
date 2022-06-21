//
//  Extensions.swift
//  Santander
//
//  Created by Serena on 21/06/2022
//
	

import Foundation
import UniformTypeIdentifiers

extension URL {
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
    
    var localizedTypeDescription: String? {
        return UTType(filenameExtension: self.pathExtension)?.localizedDescription?.localizedCapitalized
    }
    
    var typeIdentifier: String? {
        return UTType(filenameExtension: self.pathExtension)?.description
    }
}
