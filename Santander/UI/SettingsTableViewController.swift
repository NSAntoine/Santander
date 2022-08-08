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
        self.navigationController?.navigationBar.prefersLargeTitles = true
    }
    
    override init(style: UITableView.Style = .insetGrouped) {
        super.init(style: style)
        
        self.tableView.register(SettingsSwitchTableViewCell.self, forCellReuseIdentifier: SettingsSwitchTableViewCell.identifier)
        self.tableView.register(SettingsColorTableViewCell.self, forCellReuseIdentifier: SettingsColorTableViewCell.identifier)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 2
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch section {
        case 0: return 2
        case 1: return 3
        default: fatalError("How'd we get here?")
        }
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        if (indexPath.section, indexPath.row) == (1, 2) {
            return tableView.dequeueReusableCell(withIdentifier: SettingsColorTableViewCell.identifier, for: indexPath)
        }
        
        let cell = tableView.dequeueReusableCell(withIdentifier: SettingsSwitchTableViewCell.identifier, for: indexPath) as! SettingsSwitchTableViewCell
        
        switch (indexPath.section, indexPath.row) {
        case (0, 0):
            cell.label.text = "Display large navigation title"
            cell.fallback = true
            cell.defaultKey = "UseLargeNavTitles"
        case (0, 1):
            cell.label.text = "Always show search bar"
            cell.defaultKey = "AlwaysShowSearchBar"
        case (1, 0):
            cell.label.text = "Display items in plain style"
            cell.defaultKey = "usePlainStyleTableView"
        case (1, 1):
            cell.label.text = "Show information button"
            cell.defaultKey = "ShowInfoButton"
        default: break
        }
        
        return cell
    }
    
    
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch section {
        case 0: return "Navigation"
        case 1: return "Views"
        default: return nil
        }
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        switch (indexPath.section, indexPath.row) {
        case (1, 2):
            self.present(colorPickerVC, animated: true)
        default:
            break
        }
    }
}

extension SettingsTableViewController: UIColorPickerViewControllerDelegate {
    func colorPickerViewControllerDidFinish(_ viewController: UIColorPickerViewController) {
        let color = viewController.selectedColor
        
        DispatchQueue.main.async {
            UserPreferences.appTintColor = CodableColor(color)
            self.view.window?.tintColor = color
            self.tableView.reloadRows(at: [IndexPath(row: 2, section: 1)], with: .fade)
        }
    }
}

class SettingsSwitchTableViewCell: UITableViewCell {
    
    static let identifier = "SettingsSwitchTableViewCell"
    
    public var control: UISwitch = UISwitch()
    public var label: UILabel = UILabel()
    var fallback = false
    var callback: ((Bool) -> Void)? = nil
    
    
    var defaultKey: String? {
        didSet {
            if let key = defaultKey {
                control.isOn = UserDefaults.standard.object(forKey: key) as? Bool ?? fallback
            }
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        
        self.selectionStyle = .none
        label.adjustsFontSizeToFitWidth = true
        self.contentView.addSubview(control)
        self.contentView.addSubview(label)
        
        label.translatesAutoresizingMaskIntoConstraints = false
        control.translatesAutoresizingMaskIntoConstraints = false
        
        control.centerYAnchor.constraint(equalTo: self.centerYAnchor).isActive = true
        control.addTarget(self, action: #selector(self.didChange(sender:)), for: .valueChanged)
        
        label.centerYAnchor.constraint(equalTo: self.centerYAnchor).isActive = true
        label.leadingAnchor.constraint(equalTo: self.leadingAnchor, constant: 20).isActive = true
        control.leadingAnchor.constraint(equalTo: label.trailingAnchor, constant: 5).isActive = true
        control.trailingAnchor.constraint(equalTo: self.layoutMarginsGuide.trailingAnchor).isActive = true
        label.setContentHuggingPriority(UILayoutPriority(251), for: .horizontal)
        label.setContentHuggingPriority(UILayoutPriority(251), for: .vertical)
        label.setContentCompressionResistancePriority(UILayoutPriority(749), for: .horizontal)
    }
    
    @objc public func didChange(sender: UISwitch!) {
        if let defaultKey = defaultKey {
            UserDefaults.standard.set(sender.isOn, forKey: defaultKey)
        }
        callback?(sender.isOn)
    }
}

class SettingsColorTableViewCell: UITableViewCell {
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    static var identifier = "SettingsColorTableViewCell"
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: Self.identifier)
        
        self.textLabel?.text = "Tint color"
        let colorPreview = UIView(frame: CGRect(x: 0, y: 0, width: 29, height: 29))
        colorPreview.backgroundColor = UserPreferences.appTintColor.uiColor
        colorPreview.layer.cornerRadius = colorPreview.frame.size.width / 2
        colorPreview.layer.borderWidth = 1.5
        
        accessoryView = colorPreview
    }
}
