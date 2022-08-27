//
//  SerializedArrayViewController.swift
//  Santander
//
//  Created by Serena on 18/08/2022.
//

import UIKit

class SerializedArrayViewController: UITableViewController {
    let array: NSArray
    let type: SerializedDocumentViewerType
    
    init(array: NSArray, type: SerializedDocumentViewerType, title: String?) {
        self.array = array
        self.type = type
        
        super.init(style: .userPreferred)
        self.title = title
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return array.count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell()
        var conf = cell.defaultContentConfiguration()
        let item = array[indexPath.row]
        
        if item as? NSArray != nil {
            conf.text = "Array (Index \(indexPath.row))"
            cell.accessoryType = .disclosureIndicator
        } else if item as? [String: Any] != nil {
            conf.text = "Dictionary (Index \(indexPath.row))"
            cell.accessoryType = .disclosureIndicator
        } else {
            conf.text = SerializedItemType(item: item).description
        }
        
        cell.contentConfiguration = conf
        return cell
    }
    
    override func tableView(_ tableView: UITableView, shouldHighlightRowAt indexPath: IndexPath) -> Bool {
        return true
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if let arr = array[indexPath.row] as? NSArray {
            let title = "Array (Index \(indexPath.row))"
            navigationController?.pushViewController(SerializedArrayViewController(array: arr, type: type, title: title), animated: true)
        } else if let dict = array[indexPath.row] as? [String: Any] {
            let serializedDict = dict.asSerializedDictionary()
            
            let title = "Dictionary (Index \(indexPath.row))"
            let vc = SerializedDocumentViewController(dictionary: serializedDict, type: type, title: title, canEdit: false)
            navigationController?.pushViewController(vc, animated: true)
        } else {
            tableView.deselectRow(at: indexPath, animated: true)
        }
    }
}
