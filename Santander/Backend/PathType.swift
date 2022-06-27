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
        
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel)
        let createAction = UIAlertAction(title: "Create", style: .default) { _ in
            guard let name = alert.textFields?.first?.text, !name.isEmpty else {
                return
            }
            
            let urlToCreate = url.appendingPathComponent(name)
            do {
                try type.create(to: urlToCreate)
                self.tableView.reloadData()
            } catch {
                self.errorAlert(error, title: "Unable to create \(name)")
            }
        }
        
        alert.addAction(cancelAction)
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
        case unableToCreateFile
        
        var errorDescription: String? {
            switch self {
            case .unableToCreateFile:
                return "Unable to create file"
            }
        }
    }
    
    /// Creates the specified path type to the given URL.
    func create(to url: URL) throws {
        switch self {
        case .file:
            let didCreateFile = FileManager.default.createFile(atPath: url.path, contents: nil, attributes: nil)
            guard didCreateFile else {
                throw Errors.unableToCreateFile
            }
        case .directory:
            try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true, attributes: nil)
        }
    }
}
