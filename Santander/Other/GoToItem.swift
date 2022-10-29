//
//  GoToItem.swift
//  Santander
//
//  Created by Serena on 24/10/2022
//
	

import UIKit

/// An item displayed for the user in the "Go to.." menu
struct GoToItem: Hashable {
    
    /// The dictionary to describe Go To Items which may or may not exist (as in, the URL path itself may or may not exist on disk)
    private typealias MayExistDictionary = [String: (URL?, UIImage?)]
    
    let displayName: String
    let url: URL
    let image: UIImage?
    
    init(displayName: String, url: URL, image: UIImage?) {
        self.displayName = displayName
        self.url = url
        self.image = image
    }
    
    // this is here to make code below easier to read
    private static func _searchPathDirURL(_ searchPath: FileManager.SearchPathDirectory) -> URL? {
        return FileManager.default.urls(for: searchPath, in: .userDomainMask).first
    }
    
    private static func _generateAll() -> [GoToItem] {
        // these items always exist and will always be displayed
        let coreItems: [GoToItem] = [
            GoToItem(displayName: "Root", url: .root, image: nil),
            GoToItem(displayName: "Home", url: .home, image: UIImage(systemName: "house"))
        ]
  
        let mayExistDict: MayExistDictionary = [
            "Applications": (_searchPathDirURL(.applicationDirectory), .appsDirectory),
            "Library":      (_searchPathDirURL(.libraryDirectory),     .libraryDirectory),
            "Documents":    (_searchPathDirURL(.documentDirectory),    .documentDirectory),
            "Downloads":    (_searchPathDirURL(.downloadsDirectory),   .downloadsDirectory)
        ]
        
        let mayExistItems: [GoToItem] = mayExistDict.compactMap { (key, value) in
            let (url, image) = value
            guard let url = url, FileManager.default.fileExists(atPath: url.path) else {
                return nil
            }
            
            return GoToItem(displayName: key, url: url, image: image)
        }
        
        
        return coreItems + mayExistItems
    }
    
    static let all = _generateAll()
}

fileprivate extension UIImage {
    static let appsDirectory =      UIImage(systemName: "app.dashed")
    static let libraryDirectory =   UIImage(systemName: "books.vertical")
    static let documentDirectory =  UIImage(systemName: "doc")
    static let downloadsDirectory = UIImage(systemName: "arrow.down.circle")
}
