//
//  PathOperationViewController.swift
//  Santander
//
//  Created by Serena on 24/06/2022
//

import UIKit
import QuickLook

/// A View Controller which presents a path to be selected, and then executes a specified operation, such as moving or copying the path
class PathOperationViewController: PathListViewController {
    
    /// The paths being moved / copied / imported / etc.
    let paths: [URL]
    
    /// The type of the operation to perform
    let operationType: PathSelectionOperation
    
    let dismissWhenDone: Bool
    
    init(paths: [URL], operationType: PathSelectionOperation, startingPath: Path = .root, dismissWhenDone: Bool = true) {
        self.paths = paths
        self.operationType = operationType
        self.dismissWhenDone = dismissWhenDone
        
        super.init(path: startingPath)
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
        
        for path in paths {
            _ = path.startAccessingSecurityScopedResource()
        }
    }
    
    @objc func done() {
        guard let currentPath = self.currentPath else {
            self.errorAlert("Unable to get current path to \(operationType.description) to, out!", title: "Can't \(operationType.description) path")
            return
        }
        
        do {
            switch operationType {
            case .move:
                try FSOperation.perform(.moveItem(items: paths, resultPath: currentPath.url), rootHelperConf: RootConf.shared)
            case .copy, .import:
                try FSOperation.perform(.copyItem(items: paths, resultPath: currentPath.url), rootHelperConf: RootConf.shared)
            case .symlink:
                try FSOperation.perform(.symlink(items: paths, resultPath: currentPath.url), rootHelperConf: RootConf.shared)
            case .custom(_, _, let action):
                try action(self, currentPath.url)
            }
            
            if dismissWhenDone {
                self.dismiss(animated: true)
            }
        } catch {
            self.errorAlert(error, title: "Unable to \(operationType.description) items")
        }
        
    }
    
    override func goToPath(path: Path) {
        let parentDirectory = path.deletingLastPathComponent()
        
        if parentDirectory != currentPath {
            traverseThroughPath(path)
            return
        }
        
        if path.isDirectory {
            self.navigationController?.pushViewController(PathOperationViewController(paths: paths, operationType: operationType, startingPath: path, dismissWhenDone: dismissWhenDone), animated: true)
        } else {
            self.goToFile(path: path)
        }
    }
    
    override func traverseThroughPath(_ path: Path) {
        let vcs = path.url.fullPathComponents().map { [self] newPath in
            PathOperationViewController(paths: paths, operationType: operationType, startingPath: Path(url: newPath), dismissWhenDone: dismissWhenDone)
        }
        
        self.navigationController?.setViewControllers(vcs, animated: true)
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
            // if we don't do this, we may result in a memory leak
            path.stopAccessingSecurityScopedResource()
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
    
    /// Custom action
    case custom(description: String, verbDescription: String, action: (PathOperationViewController, URL) throws -> Void)
    
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
        case .custom(description: let description, _, _):
            return description
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
        case .custom(_, verbDescription: let verbDescription, _):
            return verbDescription
        }
    }
}
