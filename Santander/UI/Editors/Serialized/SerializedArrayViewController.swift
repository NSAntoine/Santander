//
//  SerializedArrayViewController.swift
//  Santander
//
//  Created by Serena on 18/08/2022.
//

import UIKit

class SerializedArrayViewController: UITableViewController {
    var array: Array<Any>
    let type: SerializedDocumentViewerType
    let fileURL: URL?
    let canEdit: Bool
    var parentController: SerializedControllerParent?
    
    init(
        array: Array<Any>,
        type: SerializedDocumentViewerType,
        parentController: SerializedControllerParent?,
        title: String?,
        fileURL: URL?,
        canEdit: Bool
    ) {
        self.array = array
        self.type = type
        self.fileURL = fileURL
        self.canEdit = canEdit
        self.parentController = parentController
        
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
        
        if item as? Array<Any> != nil {
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
        if let arr = array[indexPath.row] as? Array<Any> {
            let title = "Array (Index \(indexPath.row))"
            let vc = SerializedArrayViewController(
                array: arr,
                type: type,
                parentController: .array(self),
                title: title,
                fileURL: fileURL,
                canEdit: canEdit
            )
            
            navigationController?.pushViewController(vc, animated: true)
        } else if let dict = array[indexPath.row] as? [String: Any] {
            let serializedDict = dict.asSerializedDictionary()
            
            let title = "Dictionary (Index \(indexPath.row))"
            let vc = SerializedDocumentViewController(dictionary: serializedDict, type: type, title: title, fileURL: fileURL, parentController: .array(self), canEdit: true)
            navigationController?.pushViewController(vc, animated: true)
        } else {
            tableView.deselectRow(at: indexPath, animated: true)
        }
    }
    
    override func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        guard canEdit else {
            return nil
        }
        
        let removeAction = UIContextualAction(style: .destructive, title: nil) { _, _, completion in
            var newArr = self.array
            newArr.remove(at: indexPath.row)
            
            if self.writeToFile(newArray: newArr) {
                tableView.deleteRows(at: [indexPath], with: .fade)
                completion(true)
            } else {
                completion(false)
            }
        }
        
        removeAction.image = .remove
        return UISwipeActionsConfiguration(actions: [removeAction])
    }
    
    func writeToFile(newArray: Array<Any>) -> Bool {
        
        // if this array controller comes from a parent,
        // edit the array / dictionary in the parent to the new array given in the parameters
        if let parentController = parentController {
            let didSucceed: Bool
            
            switch parentController {
            case .dictionary(let parent):
                var parentDict = parent.serializedDict
                let key = parentDict.first { (_, value) in
                    value == .array(self.array)
                }?.key
                
                guard let key = key else {
                    return false
                }
                
                parentDict[key] = .array(newArray)
                didSucceed = parent.writeToFile(newDict: parentDict)
            case .array(let parent):
                var parentArr = parent.array
                let indx = parentArr.firstIndex { item in
                    guard let item = item as? Array<Any> else {
                        return false
                    }
                    
                    return NSArray(array: self.array) == NSArray(array: item)
                }
                
                guard let indx = indx else {
                    return false
                }
                
                parentArr[indx] = newArray
                didSucceed = parent.writeToFile(newArray: parentArr)
            }
            
            if didSucceed {
                self.array = newArray
            }
            
            return didSucceed
        }
        
        // writing to root of file
        guard let fileURL = fileURL else {
            return false
        }
        
        do {
            let newSerializedData: Data
            switch type {
            case .json:
                newSerializedData = try JSONSerialization.data(withJSONObject: newArray)
            case .plist(let format):
                guard let format = format else {
                    return false
                }
                
                newSerializedData = try PropertyListSerialization.data(fromPropertyList: newArray, format: format, options: 0)
            }
            
            try FSOperation.perform(.writeData(url: fileURL, data: newSerializedData), rootHelperConf: RootConf.shared)
            self.array = newArray
            return true
        } catch {
            self.errorAlert(error, title: "Unable to write to file")
            return false
        }
    }
}
