//
//  PropertyListViewController.swift
//  Santander
//
//  Created by Serena on 16/08/2022.
//

import UIKit

class PropertyListViewController: UITableViewController, PropertyListItemViewControllerDelegate {
    typealias PlistDictionaryType = [String: PropertyListItemType]
    
    var plistDictionary: PlistDictionaryType {
        willSet {
            keys = Array(newValue.keys)
        }
    }
    
    lazy var keys = Array(plistDictionary.keys)
    var format: PropertyListSerialization.PropertyListFormat?
    var fileURL: URL?
    var plistParent: PlistControllerParent
    
    init(style: UITableView.Style = .insetGrouped, dictionary: PlistDictionaryType, format: PropertyListSerialization.PropertyListFormat?, title: String, fileURL: URL? = nil, plistParent: PlistControllerParent) {
        self.plistDictionary = dictionary
        self.format = format
        self.fileURL = fileURL
        self.plistParent = plistParent
        
        super.init(style: style)
        self.title = title
    }
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.navigationItem.rightBarButtonItem = UIBarButtonItem(systemItem: .done, primaryAction: UIAction(withClosure: dismissVC))
        
    }
    
    convenience init?(style: UITableView.Style = .insetGrouped, fileURL: URL, parent: PlistControllerParent) {
        let fmt: UnsafeMutablePointer<PropertyListSerialization.PropertyListFormat>? = .allocate(capacity: 4)
        defer {
            fmt?.deallocate()
        }
        
        guard let data = try? Data(contentsOf: fileURL),
              let plist = try? PropertyListSerialization.propertyList(from: data, format: fmt) as? [String: Any] else {
            return nil
        }
        
        var newDict: PropertyListViewController.PlistDictionaryType = [:]
        
        for (key, value) in plist {
            newDict[key] = PropertyListItemType(item: value)
        }
        
        self.init(dictionary: newDict, format: fmt?.pointee, title: fileURL.lastPathComponent, plistParent: parent)
        self.fileURL = fileURL
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return plistDictionary.keys.count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: .value2, reuseIdentifier: nil)
        var conf = cell.defaultContentConfiguration()
        let text = keys[indexPath.row]
        
        conf.text = text
        let elem = plistDictionary[text]
        
        switch elem {
        case .dictionary(_), .array(_):
            cell.accessoryType = .disclosureIndicator
            conf.secondaryText = elem?.typeDescription
        default:
            conf.secondaryText = elem?.description
            cell.accessoryType = .detailButton
        }
        
        cell.contentConfiguration = conf
        return cell
    }
    
    func dismissVC() {
        self.dismiss(animated: true)
    }
    
    /// Present the PropertyListViewController for a specified indexPath
    func presentPlistVC(forIndexPath indexPath: IndexPath) {
        let text = keys[indexPath.row]
        let elem = plistDictionary[text]!
        
        if case .array(let arr) = elem {
            let vc = PropertyListArrayViewController(style: .insetGrouped, array: arr, title: text)
            self.navigationController?.pushViewController(vc, animated: true)
        } else if case .dictionary(let dict) = elem {
            var newDict: PlistDictionaryType = [:]
            for (key, value) in dict {
                newDict[key] = .init(item: value)
            }
            
            let vc = PropertyListViewController(dictionary: newDict, format: format, title: text, fileURL: fileURL, plistParent: .dictionary(self.plistDictionary.asAnyDictionary()))
            self.navigationController?.pushViewController(vc, animated: true)
        } else {
            let vc = PropertyListItemViewController(item: elem, itemKey: text)
            vc.delegate = self
            let navVC = UINavigationController(rootViewController: vc)
            if #available(iOS 15.0, *) {
                navVC.sheetPresentationController?.detents = [.medium()]
            }
            self.present(navVC, animated: true)
        }
    }
    
    override func tableView(_ tableView: UITableView, accessoryButtonTappedForRowWith indexPath: IndexPath) {
        presentPlistVC(forIndexPath: indexPath)
    }
    
    func didChangeName(ofItem item: String, to newName: String) {
        guard let value = plistDictionary[item] else {
            return
        }
        
        plistDictionary[item] = nil
        plistDictionary[newName] = value
        
        writePlistToFile()
        tableView.reloadData()
    }
    
    func didChangeValue(ofItem item: String, to newValue: PropertyListItemType) {
        plistDictionary[item] = newValue
        writePlistToFile()
        tableView.reloadData()
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        presentPlistVC(forIndexPath: indexPath)
    }
    
    func writePlistToFile() {
        guard let format = format, let fileURL = fileURL else {
            return
        }
        
        let selfAny: [String: Any] = plistDictionary.asAnyDictionary()
        switch plistParent {
        case .dictionary(var dict):
            let indx = dict.firstIndex { (key, value) in
                print(value, value as? [String: Any] == nil)
                if let v = value as? [String: Any] {
                    print(NSDictionary(dictionary: v), NSDictionary(dictionary: selfAny))
                    return NSDictionary(dictionary: v).isEqual(to: selfAny)
                }
                return false
            }
            
            guard let indx = indx else {
                print("indx is NIL!")
                return
            }
            
            print(indx)
            dict[dict.keys[indx]] = plistDictionary.asAnyDictionary()
            do {
                try PropertyListSerialization.data(fromPropertyList: dict, format: format, options: 0).write(to: fileURL, options: .atomic)
            } catch {
                self.errorAlert(error, title: "Unable to write to file \(fileURL.lastPathComponent)")
            }
            
        case .root:
            do {
                try PropertyListSerialization.data(fromPropertyList: self.plistDictionary.asAnyDictionary(), format: format, options: 0).write(to: fileURL, options: .atomic)
            } catch {
                self.errorAlert(error, title: "Unable to write to file \(fileURL.lastPathComponent)")
            }
        }
    }
    
    override func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        let deleteAction = UIContextualAction(style: .destructive, title: nil) { _, _, completion in
            
            self.plistDictionary[self.keys[indexPath.row]] = nil
            self.writePlistToFile()
            self.tableView.deleteRows(at: [indexPath], with: .fade)
            completion(true)
        }
        deleteAction.image = .remove
        
        return UISwipeActionsConfiguration(actions: [deleteAction])
    }
}

enum PlistControllerParent {
    case dictionary([String: Any])
    case root
}
