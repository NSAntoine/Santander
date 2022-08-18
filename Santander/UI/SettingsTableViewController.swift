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
        return 3
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch section {
        case 0, 1: return 3
        case 2: return UserPreferences.useLastOpenedPathWhenLaunching ? 1 : 2
        default: fatalError("How'd we get here?")
        }
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        switch (indexPath.section, indexPath.row) {
        case (0, 0):
            return cellWithView(settingsSwitch(forIndexPath: indexPath), text: "Large navigation titles")
        case (0, 1):
            return cellWithView(settingsSwitch(forIndexPath: indexPath), text: "Always show search bar")
        case (0, 2):
            return cellWithView(settingsSwitch(forIndexPath: indexPath), text: "Show information button")
        case (1, 0):
            let cell = UITableViewCell()
            var conf = cell.defaultContentConfiguration()
            conf.text = "Tint Color"
            cell.contentConfiguration = conf
            
            cell.accessoryView = cell.colorCircleAccessoryView(color: UserPreferences.appTintColor.uiColor)
            return cell
        case (1, 1):
            return cellWithView(setupStyleButton(), text: "Table View Style")
        case (1, 2):
            return cellWithView(setupAppearanceButton(), text: "Appearance")
        case (2, 0):
            return cellWithView(setupLaunchPathButton(), text: "Launch Path")
        case (2, 1):
            let cell = UITableViewCell(style: .value1, reuseIdentifier: nil)
            var conf = cell.defaultContentConfiguration()
            conf.text = "Custom Launch Path"
            conf.secondaryText = UserPreferences.userPreferredLaunchPath ?? "N/A"
            cell.contentConfiguration = conf
            return cell
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
    
    fileprivate func setupLaunchPathButton() -> UIButton {
        let button = UIButton()
        
        let customPathChosen = !UserPreferences.useLastOpenedPathWhenLaunching
        button.setTitle(customPathChosen ? "Custom Path" : "Last Opened Path", for: .normal)
        button.setTitleColor(.systemGray, for: .normal)
        
        let lastOpenedPathAction = UIAction(title: "Last Opened Path", state: UserPreferences.useLastOpenedPathWhenLaunching ? .on : .off) { _ in
            UserPreferences.useLastOpenedPathWhenLaunching = true
            self.tableView.reloadData()
        }
        
        let otherPathAction = UIAction(title: "Custom Path", state: customPathChosen ? .on : .off) { _ in
            UserPreferences.useLastOpenedPathWhenLaunching = false
            if UserPreferences.userPreferredLaunchPath == nil {
                self.changeCustomLaunchPathAlert()
            } else {
                self.tableView.reloadData()
            }
        }
        
        button.menu = UIMenu(children: [lastOpenedPathAction, otherPathAction])
        button.showsMenuAsPrimaryAction = true
        return button
    }
    
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch section {
        case 0: return "Views"
        case 1: return "Theming"
        case 2: return "Other"
        default: return nil
        }
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        switch (indexPath.section, indexPath.row) {
        case (1, 0):
            self.present(colorPickerVC, animated: true)
        case (2, 1):
            self.changeCustomLaunchPathAlert()
        default:
            break
        }
    }
    
    override func tableView(_ tableView: UITableView, shouldHighlightRowAt indexPath: IndexPath) -> Bool {
        return (indexPath.section, indexPath.row) == (1, 0) || (indexPath.section, indexPath.row) == (2, 1)
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
    
    fileprivate func changeCustomLaunchPathAlert() {
        let alert = UIAlertController(title: "Path", message: "Enter the other path you want to be opened at launch", preferredStyle: .alert)
        alert.addTextField()
        alert.addAction(.cancel())
        
        let applyAction = UIAlertAction(title: "Add", style: .default) { _ in
            guard let text = alert.textFields?.first?.text, !text.isEmpty else {
                self.errorAlert("Input text is invalid or empty", title: "Unable to set path as Launch Path")
                return
            }
            
            let url = URL(fileURLWithPath: text)
            guard url.isDirectory else {
                self.errorAlert("Path must be a directory", title: "Unable to set path as Launch Path")
                return
            }
            
            UserPreferences.useLastOpenedPathWhenLaunching = false
            UserPreferences.userPreferredLaunchPath = url.path
        }
        alert.addAction(applyAction)
        self.present(alert, animated: true)
    }
    
    /// Whether or not the option at the specific index path is enabled
    func switchOptionIsEnabled(forIndexPath indexPath: IndexPath) -> Bool {
        switch (indexPath.section, indexPath.row) {
        case (0, 0):
            return UserPreferences.useLargeNavigationTitles
        case (0, 1):
            return UserPreferences.alwaysShowSearchBar
        case (0, 2):
            return UserPreferences.showInfoButton
        default:
            fatalError("Got unknown index path in \(#function)! IndexPath: \(indexPath)")
        }
    }
    
    func settingsSwitch(forIndexPath indexPath: IndexPath) -> UISwitch {
        let s = UISwitch()
        s.isOn = switchOptionIsEnabled(forIndexPath: indexPath)
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
