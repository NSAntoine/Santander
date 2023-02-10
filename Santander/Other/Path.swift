//
//  Path.swift
//  Santander
//
//  Created by Serena on 10/02/2023.
//

import UIKit
import UniformTypeIdentifiers
import ApplicationsWrapper

struct Path: Hashable, ExpressibleByStringLiteral {
    static let resourceKeys: Set<URLResourceKey> = [.isDirectoryKey, .contentTypeKey]
    
    static let root: Path = "/"
    static let home: Path = Path(url: URL(fileURLWithPath: NSHomeDirectory()))
    
    var url: URL
    var lastPathComponent: String
    var isDirectory: Bool
    var contentType: UTType?
    
    lazy var size = _getSize()
    lazy var displayImage: UIImage? = _displayImage()
    
    var path: String {
        url.path
    }
    
    var displayName: String {
        FileManager.default.displayName(atPath: url.path)
    }
    
    var pathExtension: String {
        return url.pathExtension
    }
    
    var containsAppUUIDSubpaths: Bool {
        return url.pathComponents.contains("Containers") || url.pathComponents.contains("containers")
    }
   
    func deletingLastPathComponent() -> Path {
        return Path(url: url.deletingLastPathComponent())
    }
    
    func deletingPathExtension() -> Path {
        return Path(url: url.deletingPathExtension())
    }
    
    func appendingPathExtension(_ ext: String) -> Path {
        return Path(url: url.appendingPathExtension(ext))
    }
    
    func appendingPathComponent(_ component: String) -> Path {
        return Path(url: url.appendingPathComponent(component))
    }
    
    func appendingPathComponent(_ component: String) -> URL {
        return url.appendingPathComponent(component)
    }
    
    var resolvedURL: URL {
        return (try? URL(resolvingAliasFileAt: url)) ?? url
    }
    
    var contents: [Path] {
        return url.contents.map(Path.init(url:))
    }
    
    var applicationItem: LSApplicationProxy? {
        if pathExtension == "app" {
            return ApplicationsManager.shared.application(forBundleURL: self.url)
        }
        
        return ApplicationsManager.shared.application(forContainerURL: self.url) ?? ApplicationsManager.shared.application(forDataContainerURL: self.url)
    }
    
    private func _getSize() -> Int? {
        if isDirectory {
            var _size: Int = 0
            for var content in contents {
                _size += content.size ?? 0
            }
            
            return _size
        }
        
        return try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize
    }
    
    var isReadable: Bool {
        return FileManager.default.isReadableFile(atPath: url.path)
    }
    
    private func _displayImage() -> UIImage? {
        if isDirectory {
            return UIImage(systemName: "folder.fill")
        } else {
            // `UTType.data` is a generic type,
            // return the generic symbol for files for it.
            guard let type = self.contentType, type != .data else {
                return UIImage(systemName: "doc")
            }
            
            let imageName = UTType.iconsDictionary.first { (key, _) in
                type.isOfType(key)
            }?.value
            
            return UIImage(systemName: imageName ?? "doc")
        }
    }
    
    init(url: URL) {
        self.url = url
        self.lastPathComponent = url.lastPathComponent
        
        let resourceValues = try? url.resourceValues(forKeys: Self.resourceKeys)
        self.isDirectory = resourceValues?.isDirectory ?? false
        self.contentType = resourceValues?.contentType
    }
    
    init(stringLiteral value: StringLiteralType) {
        self.init(url: URL(fileURLWithPath: value))
    }
}
