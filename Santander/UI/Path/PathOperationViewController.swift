//
//  PathOperationViewController.swift
//  Santander
//
//  Created by Serena on 24/06/2022
//
	

import UIKit
import QuickLook

/// A View Controller which presents a path to be selected, and then executes a specified operation
class PathOperationViewController: PathContentsTableViewController {
    
    /// The path being moved
    let movingPath: URL
    
    /// The type of the operation to perform
    let operationType: PathSelectionOperation
    
    /// The original Path Contents View Controller to reload if moving / copying succeeds
    let sourceContentsVC: PathContentsTableViewController?
    
    init(movingPath: URL, sourceContentsVC: PathContentsTableViewController?, operationType: PathSelectionOperation, startingPath: URL) {
        self.movingPath = movingPath
        self.sourceContentsVC = sourceContentsVC
        self.operationType = operationType
        
        super.init(path: startingPath)
    }
    
    required init?(coder: NSCoder) {
        fatalError("Not implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.navigationController?.navigationBar.prefersLargeTitles = false
        self.title = self.operationType == .move ? "Moving to.." : "Copying to.."
        if let currentPath = self.currentPath {
            self.navigationItem.backBarButtonItem = UIBarButtonItem(title: currentPath.lastPathComponent, style: .plain, target: nil, action: nil)
        }
        self.navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Done", style: .done, target: self, action: #selector(done))
    }
    
    @objc func done() {
        guard let currentPath = self.currentPath else {
            self.errorAlert("Unable to get current path to \(operationType.description) to, out!", title: "Can't \(operationType.description) path")
            return
        }
        
        let destinationPath = currentPath.appendingPathComponent(movingPath.lastPathComponent)
        do {
            if operationType == .move {
                try FileManager.default.moveItem(at: movingPath, to: destinationPath)
            } else {
                try FileManager.default.copyItem(at: movingPath, to: destinationPath)
            }
            
            self.dismiss(animated: true)
        } catch {
            self.errorAlert(error, title: "Unable to \(operationType.description) \(movingPath.lastPathComponent)")
        }
    }
    
    override func goToPath(path: URL) {
        if path.isDirectory {
            self.navigationController?.pushViewController(PathOperationViewController(movingPath: movingPath, sourceContentsVC: self.sourceContentsVC, operationType: self.operationType, startingPath: path), animated: true)
        } else {
            let controller = QLPreviewController()
            let shared = FilePreviewDataSource(fileURL: path)
            controller.dataSource = shared
            self.present(controller, animated: true)
        }
    }
}

enum PathSelectionOperation: CustomStringConvertible {
    /// To move the path
    case move
    
    /// To move the path
    case copy
    
    var description: String {
        switch self {
        case .move:
            return "move"
        case .copy:
            return "copy"
        }
    }
}

extension UITableView.Style {
    static var automatic: UITableView.Style {
        return UserPreferences.usePlainStyleTableView ? .plain : .insetGrouped
    }
}
