//
//  DragAndDrop.swift
//  Santander
//
//  Created by Serena on 24/06/2022
//
	

import UIKit
import UniformTypeIdentifiers

extension PathContentsTableViewController: UITableViewDropDelegate, UITableViewDragDelegate {
    
    func tableView(_ tableView: UITableView, performDropWith coordinator: UITableViewDropCoordinator) {
        
        guard let currentPath = self.currentPath else {
            return
        }
        
        coordinator.items.first?.dragItem.itemProvider.loadFileRepresentation(forTypeIdentifier: "public.item") { url, err in
            guard let url = url, err == nil else {
                DispatchQueue.main.async {
                    self.errorAlert("Error: \(err?.localizedDescription ?? "Unknown")", title: "Failed to import file")
                }
                return
            }
            
            let newPath = currentPath
                .appendingPathComponent(url.lastPathComponent)
            
            do {
                try FileManager.default.copyItem(at: url, to: newPath)
                DispatchQueue.main.async {
                    self.unfilteredContents.append(url)
                    tableView.reloadData()
                }
            } catch {
                DispatchQueue.main.async {
                    self.errorAlert("Error: \(error.localizedDescription)", title: "Failed to copy item")
                }
            }
            
        }
    }
    
    func tableView(_ tableView: UITableView, canHandle session: UIDropSession) -> Bool {
        return currentPath != nil
    }
    
    func tableView(_ tableView: UITableView, itemsForBeginning session: UIDragSession, at indexPath: IndexPath) -> [UIDragItem] {
        let selectedItem = contents[indexPath.row]
        let itemProvider = NSItemProvider()
        
        let typeID: String
        if selectedItem.isDirectory {
            typeID = UTType.folder.identifier
        } else {
            typeID = UTType(filenameExtension: selectedItem.pathExtension)?.identifier ?? "public.content"
        }
        
        itemProvider.registerFileRepresentation(
            forTypeIdentifier: typeID,
            visibility: .all) { completion in
                completion(selectedItem, true, nil)
                return nil
            }
        
        return [
            UIDragItem(itemProvider: itemProvider)
        ]
    }
}
