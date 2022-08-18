//
//  PropertyListItemViewController.swift
//  Santander
//
//  Created by Serena on 17/08/2022.
//

import UIKit

class PropertyListItemViewController: UITableViewController {
    var item: PropertyListItemType {
        didSet {
            self.delegate?.didChangeValue(ofItem: itemKey, to: item)
        }
    }
    var itemKey: String
    
    weak var delegate: PropertyListItemViewControllerDelegate?
    
    init(style: UITableView.Style = .insetGrouped, item: PropertyListItemType, itemKey: String) {
        self.item = item
        self.itemKey = itemKey
        
        super.init(style: style)
    }
    
    required init?(coder: NSCoder) {
        fatalError()
    }
    
    override func viewDidLoad() {
        title = itemKey
    }
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    override func tableView(_ tableView: UITableView, shouldHighlightRowAt indexPath: IndexPath) -> Bool {
        return false
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        switch (indexPath.section, indexPath.row) {
        case (0, 1):
            presentEditAlert()
        default:
            break
        }
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 3
    }
    
    /// The button to present the options for changing the value of a bool
    func makeBoolChangeButton(currentItemBoolValue: Bool) -> UIButton {
        let button = UIButton()
        // actions to change between true and false
        let actions = [true, false].map { bool in
            UIAction(title: bool.description, state: currentItemBoolValue == bool ? .on : .off) { _ in
                self.item = .bool(bool)
                self.tableView.reloadRows(at: [IndexPath(row: 1, section: 0)], with: .fade)
            }
        }
        
        button.menu = UIMenu(children: actions)
        button.showsMenuAsPrimaryAction = true
        
        button.setTitle(currentItemBoolValue.description, for: .normal)
        button.setTitleColor(.systemGray, for: .normal)
        return button
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: .value1, reuseIdentifier: nil)
        var conf = cell.defaultContentConfiguration()
        switch (indexPath.section, indexPath.row) {
        case (0, 0):
            let textField = UITextField()
            textField.text = itemKey
            textField.returnKeyType = .done
            
            let action = UIAction {
                self.itemKeyTextFieldDone(textField, indexPath: indexPath)
            }
            textField.addAction(action, for: .editingDidEndOnExit)
            return cellWithView(textField, text: "Key")
        case (0, 1):
            switch item {
            case .bool(let bool):
                return cellWithView(makeBoolChangeButton(currentItemBoolValue: bool), text: "Value")
            case .string(_), .int(_), .float(_):
                return cellWithView(valueTextField(atIndexPath: indexPath), text: "Value")
            default:
                conf.text = "Value"
                conf.secondaryText = item.description
            }
        case (0, 2):
            conf.text = "Type"
            conf.secondaryText = item.typeDescription
        default:
            fatalError()
        }
        
        cell.contentConfiguration = conf
        return cell
    }
    
    func valueTextField(atIndexPath indexPath: IndexPath) -> UITextField {
        let textField = UITextField()
        
        let action = UIAction {
            self.valueTextFieldDone(textField, atIndexPath: indexPath)
        }
        
        switch item {
        case .string(let string):
            textField.text = string
            textField.returnKeyType = .done
            textField.addAction(action, for: .editingDidEndOnExit)
        case .int(let int):
            textField.keyboardType = .numberPad
            textField.text = int.description
            textField.inputAccessoryView = toolbarDoneView(doneAction: action)
        case .float(let float):
            
            textField.text = float.description
            textField.keyboardType = .decimalPad
            textField.inputAccessoryView = toolbarDoneView(doneAction: action)
        default:
            fatalError() // should never get here
        }
        
        return textField
    }
    
    /// A toolbar with a bar button item saying 'done'
    /// this is needed for non-string type textfields
    func toolbarDoneView(doneAction: UIAction) -> UIToolbar {
        let toolbar = UIToolbar()
        let flexSpace = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
        
        let doneButton = UIBarButtonItem(systemItem: .done, primaryAction: doneAction)
        
        toolbar.setItems([flexSpace, doneButton], animated: true)
        toolbar.sizeToFit()
        return toolbar
    }
    
    
    func valueTextFieldDone(_ textField: UITextField, atIndexPath indexPath: IndexPath) {
        guard let text = textField.text, !text.isEmpty else {
            return
        }
        
        switch item {
        case .string(_):
            self.item = .string(text)
        case .int(_):
            guard let num = Int(text) else { return }
            self.item = .int(num)
        case .float(_):
            guard let num = Float(text) else { return }
            self.item = .float(num)
        default:
            break
        }
        
        self.delegate?.didChangeValue(ofItem: itemKey, to: self.item)
        self.tableView.reloadRows(at: [indexPath], with: .fade)
        textField.resignFirstResponder()
    }
    
    func itemKeyTextFieldDone(_ textField: UITextField, indexPath: IndexPath) {
        guard let text = textField.text, !text.isEmpty else {
            return
        }
        
        self.delegate?.didChangeName(ofItem: itemKey, to: text)
        self.itemKey = text
        self.title = self.itemKey
        self.tableView.reloadRows(at: [indexPath], with: .fade)
        textField.resignFirstResponder()
    }
    
    func presentEditAlert() {
        let alert = UIAlertController(title: "Set value", message: nil, preferredStyle: .alert)
        alert.addAction(.cancel())
        switch item {
        case .string(let string):
            alert.addTextField { textField in
                textField.text = string
            }
        case .int(let int):
            alert.addTextField { textField in
                textField.text = int.description
                textField.keyboardType = .numberPad
            }
        case .float(let float):
            alert.addTextField { textField in
                textField.text = float.description
                textField.keyboardType = .decimalPad
            }
        default:
            return
        }
        
        let applyAction = UIAlertAction(title: "Set", style: .default) { _ in
            guard let text = alert.textFields?.first?.text, !text.isEmpty else {
                return
            }
            
            switch self.item {
            case .string(_):
                self.item = .string(text)
            case .int(_):
                guard let num = Int(text) else { return }
                self.item = .int(num)
            case .float(_):
                guard let num = Float(text) else { return }
                self.item = .float(num)
            default:
                return // should never even get here
            }
        }
        
        alert.addAction(applyAction)
        self.present(alert, animated: true)
    }
}

protocol PropertyListItemViewControllerDelegate: AnyObject {
    func didChangeName(ofItem item: String, to newName: String)
    func didChangeValue(ofItem item: String, to newValue: PropertyListItemType)
}
