//
//  SettingsTableViewController.swift
//  Santander
//
//  Created by Serena on 24/06/2022
//


import UIKit
import UniformTypeIdentifiers

class SettingsTableViewController: UITableViewController {
    
    lazy var colorPickerVC: UIColorPickerViewController = {
        let vc = UIColorPickerViewController()
        vc.selectedColor = UserPreferences.appTintColor.uiColor
        vc.delegate = self
        return vc
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.title = "Settings"
        self.navigationController?.navigationBar.prefersLargeTitles = false
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override init(style: UITableView.Style) {
        super.init(style: style)
    }
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 2
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch section {
        case 0: return 3
        case 1: return 3
        default: fatalError("How'd we get here?")
        }
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        switch (indexPath.section, indexPath.row) {
        case (0, 0):
            return setupCell(withComplimentaryView: settingsSwitch(forIndexPath: indexPath), text: "Large navigation titles")
        case (0, 1):
            return setupCell(withComplimentaryView: settingsSwitch(forIndexPath: indexPath), text: "Always show search bar")
        case (0, 2):
            return setupCell(withComplimentaryView: settingsSwitch(forIndexPath: indexPath), text: "Show information button")
        case (1, 0):
            let cell = UITableViewCell()
            var conf = cell.defaultContentConfiguration()
            conf.text = "Tint Color"
            cell.contentConfiguration = conf
            
            let colorPreview = UIView(frame: CGRect(x: 0, y: 0, width: 29, height: 29))
            colorPreview.backgroundColor = UserPreferences.appTintColor.uiColor
            colorPreview.layer.cornerRadius = colorPreview.frame.size.width / 2
            colorPreview.layer.borderWidth = 1.5
            colorPreview.layer.borderColor = UIColor.systemGray.cgColor
            cell.accessoryView = colorPreview
            return cell
        case (1, 1):
            return setupCell(withComplimentaryView: setupStyleButton(), text: "Table View Style")
        case (1, 2):
            return setupCell(withComplimentaryView: setupAppearanceButton(), text: "Appearance")
        default: fatalError()
        }
    }
    
    fileprivate func setupAppearanceButton() -> UIButton {
        let button = UIButton()
        let currentStyle = UIUserInterfaceStyle(rawValue: UserPreferences.preferredInterfaceStyle) ?? .unspecified
        button.setTitle(currentStyle.description, for: .normal)
        button.setTitleColor(.systemGray, for: .normal)
        
        let chosenStyle = UserPreferences.preferredInterfaceStyle
        let actions = UIUserInterfaceStyle.allCases.map { style in
            return UIAction(title: style.description, state: chosenStyle == style.rawValue ? .on : .off) { _ in
                self.view.window?.overrideUserInterfaceStyle = style
                UserPreferences.preferredInterfaceStyle = style.rawValue
                self.tableView.reloadRows(at: [IndexPath(row: 2, section: 1)], with: .fade)
            }
        }
        
        button.menu = UIMenu(children: actions)
        button.showsMenuAsPrimaryAction = true
        return button
    }
    
    fileprivate func setupStyleButton() -> UIButton {
        let button = UIButton()
        let selectedStyle = UITableView.Style.userPreferred
        
        button.setTitle(selectedStyle.description, for: .normal)
        button.setTitleColor(.systemGray, for: .normal)
        let actions = UITableView.Style.allCases.map { style in
            return UIAction(title: style.description, state: selectedStyle == style ? .on : .off) { _ in
                UserPreferences.preferredTableViewStyle = style.rawValue
                self.tableView.reloadRows(at: [IndexPath(row: 1, section: 1)], with: .none)
            }
        }
        
        button.menu = UIMenu(children: actions)
        button.showsMenuAsPrimaryAction = true
        return button
    }
    
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch section {
        case 0: return "Views"
        case 1: return "Theming"
        default: return nil
        }
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        switch (indexPath.section, indexPath.row) {
        case (1, 0):
            self.present(colorPickerVC, animated: true)
        default:
            break
        }
    }
    
    override func tableView(_ tableView: UITableView, shouldHighlightRowAt indexPath: IndexPath) -> Bool {
        return (indexPath.section, indexPath.row) == (1, 0)
    }
    
    func setupCell(withComplimentaryView view: UIView, text: String) -> UITableViewCell {
        let cell = UITableViewCell()
        var conf = cell.defaultContentConfiguration()
        conf.text = text
        cell.contentConfiguration = conf
        view.translatesAutoresizingMaskIntoConstraints = false
        cell.contentView.addSubview(view)
        
        NSLayoutConstraint.activate([
            view.rightAnchor.constraint(equalTo: cell.contentView.rightAnchor, constant: -20),
            view.centerYAnchor.constraint(equalTo: cell.contentView.centerYAnchor)
        ])
        
        return cell
    }
    
    func defaultsKey(forIndexPath indexPath: IndexPath) -> String {
        switch (indexPath.section, indexPath.row) {
        case (0, 0):
            return "UseLargeNavTitles"
        case (0, 1):
            return "AlwaysShowSearchBar"
        case (0, 2):
            return "ShowInfoButton"
        default:
            fatalError()
        }
        
    }
    
    func settingsSwitch(forIndexPath indexPath: IndexPath) -> UISwitch {
        let s = UISwitch()
        s.isOn = UserDefaults.standard.bool(forKey: defaultsKey(forIndexPath: indexPath))
        let action = UIAction { _ in
            UserDefaults.standard.set(s.isOn, forKey: self.defaultsKey(forIndexPath: indexPath))
        }
        
        s.addAction(action, for: .valueChanged)
        return s
    }
}

extension SettingsTableViewController: UIColorPickerViewControllerDelegate {
    func colorPickerViewControllerDidFinish(_ viewController: UIColorPickerViewController) {
        let color = viewController.selectedColor
        
        DispatchQueue.main.async {
            UserPreferences.appTintColor = CodableColor(color)
            self.view.window?.tintColor = color
            self.tableView.reloadRows(at: [IndexPath(row: 0, section: 1)], with: .fade)
        }
    }
}
