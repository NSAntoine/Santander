//
//  SettingsTableViewController.swift
//  Santander
//
//  Created by Serena on 24/06/2022
//


import UIKit
import UniformTypeIdentifiers

class SettingsTableViewController: UITableViewController {
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.title = "Settings"
        self.navigationController?.navigationBar.prefersLargeTitles = true
    }
    
    override init(style: UITableView.Style = .insetGrouped) {
        super.init(style: style)
        
        self.tableView.register(SettingsSwitchTableViewCell.self, forCellReuseIdentifier: SettingsSwitchTableViewCell.identifier)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch section {
        case 0: return 2
        default: fatalError("How'd we get here?")
        }
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: SettingsSwitchTableViewCell.identifier, for: indexPath) as! SettingsSwitchTableViewCell
        
        switch (indexPath.section, indexPath.row) {
        case (0, 0):
            cell.label.text = "Display large navigation title"
            cell.fallback = true
            cell.defaultKey = "UseLargeNavTitles"
        case (0, 1):
            cell.label.text = "Always show search bar"
            cell.defaultKey = "AlwaysShowSearchBar"
        default: break
        }
        
        return cell
    }
    
    
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch section {
        case 0: return "Navigation"
        default: return nil
        }
    }
}

class SettingsSwitchTableViewCell: UITableViewCell {
    
    static let identifier = "SettingsSwitchTableViewCell"
    
    public var control: UISwitch = UISwitch()
    public var label: UILabel = UILabel()
    var viewControllerForPresentation: UIViewController?
    var fallback = false
    
    var defaultKey: String? {
        didSet {
            if let key = defaultKey { control.isOn = UserDefaults.standard.object(forKey: key) as? Bool ?? fallback }
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
    }
}
