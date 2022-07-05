//
//  EditorThemeSettingsViewController.swift
//  Santander
//
//  Created by Serena on 03/07/2022
//
	

import UIKit
import Runestone

class EditorThemeSettingsViewController: UITableViewController {
    
    weak var delegate: EditorThemeSettingsDelegate?
    
    var theme: CodableTheme
    
    init(style: UITableView.Style, theme: CodableTheme) {
        self.theme = theme
        super.init(style: style)
        
        self.tableView.register(SettingsSwitchTableViewCell.self, forCellReuseIdentifier: SettingsSwitchTableViewCell.identifier)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) hasn't been implemented.")
    }
    
    override func viewDidLoad() {
        self.title = "Text Editor Settings"
    }
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 2
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch section {
        case 0: return 2
        case 1: return 2
        default: fatalError("How the hell did you get here?! Unhandled section: \(section)")
        }
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: .value1, reuseIdentifier: nil)
        var conf = cell.defaultContentConfiguration()
        switch (indexPath.section, indexPath.row) {
        case (0, 0):
            conf.text = "Font"
            conf.secondaryText = theme.font.font.fontName
        case (0, 1):
            conf.text = "Font size"
            let stepper = UIStepper()
            stepper.value = theme.font.font.pointSize
            stepper.addTarget(self, action: #selector(fontStepperValueChanged(sender:)), for: .valueChanged)
            cell.accessoryView = stepper
            conf.secondaryText = theme.font.font.pointSize.description
        case (1, 0):
            let cell = tableView.dequeueReusableCell(withIdentifier: SettingsSwitchTableViewCell.identifier) as! SettingsSwitchTableViewCell
            cell.label.text = "Show line count"
            cell.defaultKey = "TextEditorShowLineCount"
            cell.fallback = true
            cell.callback = { isOn in
                self.delegate?.showLineCountConfigurationDidChange(showLineCount: isOn)
            }
            return cell
        case (1, 1):
            let cell = tableView.dequeueReusableCell(withIdentifier: SettingsSwitchTableViewCell.identifier) as! SettingsSwitchTableViewCell
            cell.label.text = "Wrap lines"
            cell.defaultKey = "TextEditorWrapLines"
            cell.fallback = true
            cell.callback = { isOn in
                self.delegate?.wrapLinesConfigurationDidChange(wrapLines: isOn)
            }
            return cell
        default: break
        }
        cell.contentConfiguration = conf
        return cell
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        switch (indexPath.section, indexPath.row) {
        case (0, 0):
            let vc = UIFontPickerViewController()
            vc.delegate = self
            self.present(vc, animated: true)
        default: break
        }
    }
    
    @objc
    func fontStepperValueChanged(sender: UIStepper) {
        let val = sender.value
        self.theme.font = CodableFont(self.theme.font.font.withSize(val)) // set the theme font
        
        // the index path containing the stepper,
        // to be reloaded
        let stepperCellIndexPath = IndexPath(row: 1, section: 0)
        self.tableView.reloadRows(at: [stepperCellIndexPath], with: .none)
        delegate?.themeDidChange(to: self.theme)
    }
}

extension EditorThemeSettingsViewController: UIFontPickerViewControllerDelegate {
    func fontPickerViewControllerDidPickFont(_ viewController: UIFontPickerViewController) {
        viewController.dismiss(animated: true) // Dismiss the vc
        // Make sure we got the descriptor
        guard let descriptor = viewController.selectedFontDescriptor else { return }
        let existingFontSize = self.theme.font.font.pointSize
        self.theme.font = CodableFont(UIFont(descriptor: descriptor, size: existingFontSize))
        
        let fontNameIndexPath = IndexPath(row: 0, section: 0)
        self.tableView.reloadRows(at: [fontNameIndexPath], with: .none)
        delegate?.themeDidChange(to: self.theme)
    }
}

protocol EditorThemeSettingsDelegate: AnyObject {
    func themeDidChange(to newTheme: CodableTheme)
    func wrapLinesConfigurationDidChange(wrapLines: Bool)
    func showLineCountConfigurationDidChange(showLineCount: Bool)
}
