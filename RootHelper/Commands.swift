//
//  Commands.swift
//  RootHelper
//
//  Created by Serena on 10/11/2022
//
	

import Foundation
import ArgumentParser
import CompressionWrapper
import AssetCatalogWrapper

struct Delete: ParsableCommand {
    @Argument(help: "The paths to delete.")
    var paths: [URL]
    
    func run() throws {
        for path in paths {
            try FileManager.default.removeItem(at: path)
            
        }
    }
}

struct SetOwnerOrGroup: ParsableCommand {
    @Argument(help: "The path to set the owner and/or group for.")
    var path: URL
    
    @Option(help: "The name of the group to set.")
    var groupName: String?
    
    @Option(help: "The name of the owner to set for this path.")
    var ownerName: String?
    
    func run() throws {
        if let groupName = groupName {
            try FileManager.default.setAttributes([.groupOwnerAccountName: groupName], ofItemAtPath: path.path)
        }
        
        if let ownerName = ownerName {
            try FileManager.default.setAttributes([.ownerAccountName: ownerName], ofItemAtPath: path.path)
        }
    }
}

struct Create: ParsableCommand {
    @Option(help: "The directories to create.")
    var directories: [URL] = []
    
    @Option(help: "The files to create")
    var files: [URL] = []
    
    func run() throws {
        for dir in directories {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        
        for file in files {
            // mode a: create if doesn't exist
            guard let fPtr = fopen((file as NSURL).fileSystemRepresentation, "a") else {
                throw StringError("Failed to create file \(file): \(String(cString: strerror(errno)))")
            }
            
            fclose(fPtr)
        }
    }
}

struct Move: ParsableCommand {
    @Argument(help: "The paths to move.")
    var paths: [URL]
    
    @Option(help: "The destination directory to move the paths into")
    var destination: URL
    
    func run() throws {
        for path in paths {
            try FileManager.default.moveItem(at: path, to: destination.appendingPathComponent(path.lastPathComponent))
        }
    }
}

struct Copy: ParsableCommand {
    @Argument(help: "The paths to copy")
    var paths: [URL]
    
    @Option(help: "The destination to copy the paths to.")
    var destination: URL
    
    func run() throws {
        for path in paths {
            try FileManager.default.copyItem(at: path, to: destination.appendingPathComponent(path.lastPathComponent))
        }
    }
}

struct Link: ParsableCommand {
    @Argument(help: "The paths to link.")
    var paths: [URL]
    
    @Option(help: "The destination")
    var destination: URL
    
    func run() throws {
        for path in paths {
            try FileManager.default.createSymbolicLink(at: destination.appendingPathComponent(path.lastPathComponent), withDestinationURL: path)
        }
    }
}

struct SetPermissions: ParsableCommand {
    @Argument(help: "The path to set the permisions for.")
    var path: URL
    
    @Argument(help: "The permissions to set.")
    var permissions: Int
    
    func run() throws {
        try FileManager.default.setAttributes([.posixPermissions: permissions], ofItemAtPath: path.path)
    }
}

struct WriteData: ParsableCommand {
    @Argument(help: "The path to write the data into.")
    var path: URL
    
    func run() throws {
        let data = FileHandle.standardInput.availableData
        try data.write(to: path)
    }
}

struct WriteString: ParsableCommand {
    @Argument(help: "The string to write.")
    var string: String
    
    @Option(help: "The path to write the string to.")
    var path: URL
    
    func run() throws {
        try string.write(to: path, atomically: true, encoding: .utf8)
    }
}

struct Compress: ParsableCommand {
    @Option(help: "The paths to compress")
    var paths: [URL]
    
    @Option(help: "The destination of the compressed paths")
    var destination: URL
    
    @Option(help: "The compression format to use.")
    var format: Compression.FormatType = .zip
    
    func run() throws {
        try Compression.shared.compress(paths: paths, outputPath: destination, format: format)
    }
}

struct Decompress: ParsableCommand {
    @Argument(help: "The path to decompress.")
    var path: URL
    
    @Option(help: "The destination path.")
    var destination: URL
    
    func run() throws {
        try Compression.shared.extract(path: path, to: destination)
    }
}

struct ExtractCatalog: ParsableCommand {
    @Argument(help: "The path of the asset catalog file to extract.")
    var path: URL
    
    @Option(help: "The destination")
    var destination: URL
    
    func run() throws {
        let (_, renditions) = try AssetCatalogWrapper.shared.renditions(forCarArchive: path)
        let codable = renditions.flatMap(\.renditions).toCodable()
        
        try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
        var failedItems: [String: String] = [:]
        for rend in codable {
            let newURL = destination.appendingPathComponent(rend.renditionName)
            if let data = rend.itemData {
                do {
                    try data.write(to: newURL)
                } catch {
                    failedItems[rend.renditionName] = "Unable to write item data to file: \(error.localizedDescription)"
                }
            }
        }
        
        if !failedItems.isEmpty {
            var message: String = ""
            for (item, error) in failedItems {
                message.append("\(item): \(error)")
            }
            
            throw StringError(message.trimmingCharacters(in: .whitespacesAndNewlines))
        }
    }
}

struct GetContents: ParsableCommand {
    @Argument(help: "The path to get the contents of.")
    var path: URL
    
    func run() throws {
        let contents = try FileManager.default.contentsOfDirectory(at: path,
                                                                   includingPropertiesForKeys: nil)
        print(contents.map(\.path).joined(separator: " "))
    }
}
