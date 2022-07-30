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
    
    /// The path being moved
    let movingPath: URL
    
    /// The type of the operation to perform
    let operationType: PathSelectionOperation
    
    /// The original Path Contents View Controller to reload if moving / copying succeeds
    let sourceContentsVC: SubPathsTableViewController?
    
    init(movingPath: URL, sourceContentsVC: SubPathsTableViewController?, operationType: PathSelectionOperation, startingPath: URL = .root) {
        self.movingPath = movingPath
        self.sourceContentsVC = sourceContentsVC
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
    }
    
    @objc func done() {
        guard let currentPath = self.currentPath else {
            self.errorAlert("Unable to get current path to \(operationType.description) to, out!", title: "Can't \(operationType.description) path")
            return
        }
        
        let destinationPath = currentPath.appendingPathComponent(movingPath.lastPathComponent)
        do {
            switch operationType {
            case .move:
                try FileManager.default.moveItem(at: movingPath, to: destinationPath)
            case .copy, .import:
                try FileManager.default.copyItem(at: movingPath, to: destinationPath)
            case .symlink:
                try FileManager.default.createSymbolicLink(at: destinationPath, withDestinationURL: movingPath)
            }
            
            self.dismiss(animated: true)
        } catch {
            self.errorAlert(error, title: "Unable to \(operationType.description) \(movingPath.lastPathComponent)")
        }
    }
    
    override func goToPath(path: URL, pushingToSplitViewVC: Bool = false) {
        if path.isDirectory {
            self.navigationController?.pushViewController(PathOperationViewController(movingPath: movingPath, sourceContentsVC: self.sourceContentsVC, operationType: self.operationType, startingPath: path), animated: true)
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

extension UITableView.Style {
    static var automatic: UITableView.Style {
        return UserPreferences.usePlainStyleTableView ? .plain : .insetGrouped
    }
}
