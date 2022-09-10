//
//  PathType.swift
//  Santander
//
//  Created by Serena on 27/06/2022
//
	

import UIKit

extension UITableViewController {
    /// Presents an alert to create a new path based on the path type
    func presentAlertAndCreate(type: PathType, forURL url: URL) {
        let alert = UIAlertController(title: "New \(type.description)", message: nil, preferredStyle: .alert)
        alert.addTextField { textField in
            textField.placeholder = "name"
        }
        
        let createAction = UIAlertAction(title: "Create", style: .default) { _ in
            guard let name = alert.textFields?.first?.text, !name.isEmpty else {
                return
            }
            
            let urlToCreate = url.appendingPathComponent(name)
            do {
                try type.create(to: urlToCreate)
            } catch {
                self.errorAlert(error, title: "Unable to create \(name)")
            }
        }
        
        alert.addAction(.cancel())
        alert.addAction(createAction)
        self.present(alert, animated: true)
    }
}

enum PathType: CustomStringConvertible {
    case file, directory
    
    var description: String {
        switch self {
        case .file:
            return "file"
        case .directory:
            return "directory"
        }
    }
    
    enum Errors: Error, LocalizedError {
        case unableToCreateFile(fileName: String, error: String)
        
        var errorDescription: String? {
            switch self {
            case .unableToCreateFile(let name, let error):
                return "Unable to create file \(name): \(error)"
            }
        }
    }
    
    /// Creates the specified path type to the given URL.
    func create(to url: URL) throws {
        switch self {
        case .file:
            // FileManager.default.createFile doesn't throw an error, just returns a bool
            // so instead use fopen to get the error with errno if one did occur
            let file = fopen(url.path, "a");
            defer {
                fclose(file)
            }
            
            guard errno == 0 else {
                let error = String(cString: strerror(errno))
                throw Errors.unableToCreateFile(fileName: url.lastPathComponent, error: error)
            }
        case .directory:
            try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true, attributes: nil)
        }
    }
}
