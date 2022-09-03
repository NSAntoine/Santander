//
//  PropertyListItemViewController.swift
//  Santander
//
//  Created by Serena on 17/08/2022.
//

import UIKit

class SerializedItemViewController: UITableViewController {
    var item: SerializedItemType
    var itemKey: String
    
    weak var delegate: SerializedItemViewControllerDelegate?
    
    init(item: SerializedItemType, itemKey: String) {
        self.item = item
        self.itemKey = itemKey
        
        super.init(style: .grouped)
    }
    
    required init?(coder: NSCoder) {
        fatalError()
    }
    
    
    func setItem(to newValue: SerializedItemType) {
        if self.delegate?.didChangeValue(ofItem: itemKey, to: newValue) ?? false {
            item = newValue
            tableView.reloadRows(at: [IndexPath(row: 0, section: 1)], with: .fade)
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        title = itemKey
    }
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 3
    }
    
    override func tableView(_ tableView: UITableView, shouldHighlightRowAt indexPath: IndexPath) -> Bool {
        return false
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 1
    }
    
    /// The button to present the options for changing the value of a bool
    func makeBoolChangeButton(currentItemBoolValue: Bool) -> UIButton {
        let button = UIButton()
        // actions to change between true and false
        let actions = [true, false].map { bool in
            UIAction(title: bool.description, state: currentItemBoolValue == bool ? .on : .off) { _ in
                self.setItem(to: .bool(bool))
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
        
        switch indexPath.section {
        case 0:
            let textField = UITextField(frame: cell.frame)
            textField.text = itemKey
            textField.returnKeyType = .done
            
            let action = UIAction {
                self.itemKeyTextFieldDone(textField, indexPath: indexPath)
            }
            textField.addAction(action, for: .editingDidEndOnExit)
            cell.contentView.addSubview(textField)
            
            textField.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                textField.leadingAnchor.constraint(equalTo: cell.contentView.layoutMarginsGuide.leadingAnchor),
                textField.centerYAnchor.constraint(equalTo: cell.contentView.centerYAnchor)
            ])
            
            return cell
        case 1:
            switch item {
            case .bool(let bool):
                return cellWithView(makeBoolChangeButton(currentItemBoolValue: bool), text: "Value")
            case .string(let string):
                let textView = UITextView(frame: cell.frame)
                textView.text = string
                textView.font = .systemFont(ofSize: UIFont.systemFontSize)
                textView.backgroundColor = cell.backgroundColor
                textView.autoresizingMask = [.flexibleHeight, .flexibleWidth]
                textView.isScrollEnabled = true
                
                let editTextAction = UIAction {
                    guard let text = textView.text else {
                        return
                    }
                    
                    self.setItem(to: .string(text))
                    textView.resignFirstResponder()
                }
                
                textView.inputAccessoryView = toolbarDoneView(doneAction: editTextAction)
                cell.contentView.addSubview(textView)
                return cell
            case .int(_), .float(_):
                return cellWithView(valueTextField(atIndexPath: indexPath), text: "Value")
            case .date(let date):
                let datePicker = UIDatePicker()
                datePicker.date = date
                
                let action = UIAction {
                    self.setItem(to: .date(datePicker.date))
                }
                
                datePicker.addAction(action, for: .editingDidEnd)
                return cellWithView(datePicker, text: "Value")
            default:
                conf.text = "Value"
                conf.secondaryText = item.description
            }
        case 2:
            conf.text = "Type"
            conf.secondaryText = item.typeDescription
        default:
            fatalError()
        }
        
        cell.contentConfiguration = conf
        return cell
    }
    
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch section {
        case 0:
            return "Key"
        case 1:
            return "Value"
        case 2:
            return "Type"
        default:
            return nil
        }
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
            setItem(to: .string(text))
        case .int(_):
            guard let num = Int(text) else { return }
            setItem(to: .int(num))
        case .float(_):
            guard let num = Float(text) else { return }
            setItem(to: .float(num))
        default:
            break
        }
        
        textField.resignFirstResponder()
    }
    
    func itemKeyTextFieldDone(_ textField: UITextField, indexPath: IndexPath) {
        guard let text = textField.text, !text.isEmpty else {
            return
        }
        
        if self.delegate?.didChangeName(ofItem: itemKey, to: text) ?? false {
            self.itemKey = text
            self.title = self.itemKey
            self.tableView.reloadRows(at: [indexPath], with: .fade)
        }
        
        textField.resignFirstResponder()
    }
    
}

protocol SerializedItemViewControllerDelegate: AnyObject {
    func didChangeName(ofItem item: String, to newName: String) -> Bool
    func didChangeValue(ofItem item: String, to newValue: SerializedItemType) -> Bool
}
