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
                
                if self.isFavouritePathsSheet {
                    // importing to favourites
                    UserPreferences.favouritePaths.append(url.path)
                    self.unfilteredContents = UserPreferences.favouritePaths.map { URL(fileURLWithPath: $0) }
                    DispatchQueue.main.async {
                        tableView.reloadData()
                    }
                } else {
                    // copying to the current path
                    guard let currentPath = self.currentPath else {
                        return
                    }
                    
                    let newPath = currentPath.appendingPathComponent(url.lastPathComponent)
                    
                    do {
                        try FileManager.default.copyItem(at: url, to: newPath)
                    } catch {
                        DispatchQueue.main.async {
                            self.errorAlert("Error: \(error.localizedDescription)", title: "Failed to copy item")
                        }
                    }
                }
            }
        }
    }
    
    func tableView(_ tableView: UITableView, canHandle session: UIDropSession) -> Bool {
        return currentPath != nil || isFavouritePathsSheet
    }
    
    func tableView(_ tableView: UITableView, itemsForBeginning session: UIDragSession, at indexPath: IndexPath) -> [UIDragItem] {
        // if doDisplaySearchSuggestions is true, that means a search suggestion is being dragged
        guard !doDisplaySearchSuggestions else {
            return []
        }
        
        let selectedItem = contents[indexPath.row]
        let itemProvider = NSItemProvider()
        
        guard let typeID = selectedItem.contentType?.identifier else {
            return [] // if we can't get the identifier, bail
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
