//
//  PathOperationViewController.swift
//  Santander
//
//  Created by Serena on 24/06/2022
//
	

import UIKit
import QuickLook

/// A View Controller which presents a path to be selected, and then executes a specified operation, such as moving or copying the path
class PathOperationViewController: SubPathsTableViewController {
    
    /// The paths being moved / copied / imported / etc.
    let paths: [URL]
    
    /// The type of the operation to perform
    let operationType: PathSelectionOperation
    
    init(paths: [URL], operationType: PathSelectionOperation, startingPath: URL = .root) {
        self.paths = paths
        self.operationType = operationType
        
        super.init(path: startingPath) // Start from root
    }
    
    required init?(coder: NSCoder) {
        fatalError("Not implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.navigationController?.navigationBar.prefersLargeTitles = false
        self.title = self.operationType.verbDescription
        if let currentPath = self.currentPath {
            self.navigationItem.backBarButtonItem = UIBarButtonItem(title: currentPath.lastPathComponent, style: .plain, target: nil, action: nil)
        }
        
        self.navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(cancel))
        
        for path in paths {
            _ = path.startAccessingSecurityScopedResource()
        }
    }
    
    @objc func done() {
        guard let currentPath = self.currentPath else {
            self.errorAlert("Unable to get current path to \(operationType.description) to, out!", title: "Can't \(operationType.description) path")
            return
        }
        
        // in case we get errors while operating on one or multiple paths,
        // save the path and the errors in a dictionary
        var failedPaths: [String: Error] = [:]
        for path in paths {
            let destinationPath = currentPath.appendingPathComponent(path.lastPathComponent)
            do {
                switch operationType {
                case .move:
                    try FileManager.default.moveItem(at: path, to: destinationPath)
                case .copy, .import:
                    try FileManager.default.copyItem(at: path, to: destinationPath)
                case .symlink:
                    try FileManager.default.createSymbolicLink(at: destinationPath, withDestinationURL: path)
                }
            } catch {
                failedPaths[path.lastPathComponent] = error
            }
        }
        
        if !failedPaths.isEmpty {
            let alert = UIAlertController(title: "Failed to \(operationType.description) \(failedPaths.count) item(s)", message: "", preferredStyle: .alert)
            for (path, error) in failedPaths {
                alert.message?.append("\(path): \(error.localizedDescription)\n")
            }
            
            let okAction = UIAlertAction(title: "OK", style: .cancel) { _ in
                self.dismiss(animated: true)
            }
            
            alert.addAction(okAction)
            self.present(alert, animated: true)
        } else {
            self.dismiss(animated: true)
        }
    }
    
    override func goToPath(path: URL, pushingToSplitView: Bool = false) {
        if path.isDirectory {
            self.navigationController?.pushViewController(PathOperationViewController(paths: paths, operationType: self.operationType, startingPath: path), animated: true)
        } else {
            self.goToFile(path: path)
        }
    }
    
    @objc
    func cancel() {
        self.dismiss(animated: true)
    }
    
    override func setRightBarButton() {
        let doneButton = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(done))
        let options = UIBarButtonItem(image: .init(systemName: "ellipsis.circle"), menu: makeRightBarButton())
        self.navigationItem.rightBarButtonItems = [doneButton, options]
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        
        for path in paths {
            path.stopAccessingSecurityScopedResource() // if we don't do this, we may result in a memory leak
        }
    }
}

enum PathSelectionOperation: CustomStringConvertible {
    /// To move the path
    case move
    
    /// To move the path
    case copy
    
    /// To import the path
    case `import`
    
    /// To create a symbolic link to the path
    case symlink
    
    var description: String {
        switch self {
        case .move:
            return "move"
        case .copy:
            return "copy"
        case .import:
            return "import"
        case .symlink:
            return "symlink"
        }
    }
    
    var verbDescription: String {
        switch self {
        case .move:
            return "Moving to.."
        case .copy:
            return "Copying to.."
        case .import:
            return "Importing to.."
        case .symlink:
            return "Aliasing to.."
        }
    }
}
