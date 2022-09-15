//
//  DragAndDrop.swift
//  Santander
//
//  Created by Serena on 24/06/2022
//


import UIKit
import UniformTypeIdentifiers

extension SubPathsTableViewController: UITableViewDropDelegate, UITableViewDragDelegate {
    
    func tableView(_ tableView: UITableView, performDropWith coordinator: UITableViewDropCoordinator) {
        for item in coordinator.items {
            item.dragItem.itemProvider.loadFileRepresentation(forTypeIdentifier: "public.item") { url, err in
                guard let url = url, err == nil else {
                    DispatchQueue.main.async {
                        self.errorAlert("Error: \(err?.localizedDescription ?? "Unknown")", title: "Failed to import file")
                    }
                    return
                }
                
                // copying to the current path
                guard let currentPath = self.currentPath else {
                    return
                }
                
                let newPath = currentPath.appendingPathComponent(url.lastPathComponent)
                
                do {
                    try FSOperation.perform(.moveItem(resultPath: newPath), url: url)
                } catch {
                    DispatchQueue.main.async {
                        self.errorAlert("Error: \(error.localizedDescription)", title: "Failed to copy item")
                    }
                }
            }
        }
    }
    
    func tableView(_ tableView: UITableView, canHandle session: UIDropSession) -> Bool {
        return currentPath != nil
    }
    
    func tableView(_ tableView: UITableView, itemsForBeginning session: UIDragSession, at indexPath: IndexPath) -> [UIDragItem] {
        // if displayingSearchSuggestions is true, that means a search suggestion is being dragged
        guard !displayingSearchSuggestions else {
            return []
        }
        
        let selectedItem = contents[indexPath.row]
        let itemProvider = NSItemProvider()
        
        let typeID = selectedItem.contentType?.identifier ?? UTType.content.identifier
        
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
