//
//  PathType.swift
//  Santander
//
//  Created by Serena on 27/06/2022
//
	

import UIKit

extension UIViewController {
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
                switch type {
                case .file:
                    try FSOperation.perform(.createFile(files: [urlToCreate]), rootHelperConf: RootConf.shared)
                case .directory:
                    try FSOperation.perform(.createDirectory(directories: [urlToCreate]), rootHelperConf: RootConf.shared)
                }
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
}
