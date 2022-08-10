//
//  TextEditorThemeSettingsViewController.swift
//  Santander
//
//  Created by Serena on 03/07/2022
//
	

import UIKit
import Runestone

class TextEditorThemeSettingsViewController: SettingsTableViewController {
    
    weak var delegate: EditorThemeSettingsDelegate?
    var selectedIndexPath: IndexPath? = nil
    var theme: CodableTheme
    
    init(style: UITableView.Style, theme: CodableTheme) {
        self.theme = theme
        super.init(style: style)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) hasn't been implemented.")
    }
    
    override func viewDidLoad() {
        self.title = "Text Editor Settings"
    }
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 3
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch section {
        case 0, 1, 2: return 2
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
            return setupCell(withComplimentaryView: settingsSwitch(forIndexPath: indexPath), text: "Show line count")
        case (1, 1):
            return setupCell(withComplimentaryView: settingsSwitch(forIndexPath: indexPath), text: "Wrap lines")
        case (2, 0):
            conf.text = "Text Color"
            cell.accessoryView = cell.colorCircleAccessoryView(color: theme.textColor.uiColor)
        case (2, 1):
            conf.text = "Editor Background Color"
            cell.accessoryView = cell.colorCircleAccessoryView(color: theme.textEditorBackgroundColor.uiColor)
        default: break
        }
        
        cell.contentConfiguration = conf
        return cell
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        self.selectedIndexPath = indexPath
        if indexPath.section == 2 {
            let vc = UIColorPickerViewController()
            switch indexPath.row {
            case 0:
                vc.selectedColor = theme.textColor.uiColor
            case 1:
                vc.selectedColor = theme.textEditorBackgroundColor.uiColor
            default:
                break
            }
            
            vc.delegate = self
            self.present(vc, animated: true)
            return
        }
        
        switch (indexPath.section, indexPath.row) {
        case (0, 0):
            let vc = UIFontPickerViewController()
            vc.delegate = self
            self.present(vc, animated: true)
        default: break
        }
    }
    
    override func settingsSwitch(forIndexPath indexPath: IndexPath) -> UISwitch {
        let s = super.settingsSwitch(forIndexPath: indexPath)
        
        let action = UIAction {
            UserDefaults.standard.set(s.isOn, forKey: self.defaultsKey(forIndexPath: indexPath))
            switch indexPath.row {
            case 0:
                self.delegate?.showLineCountConfigurationDidChange(showLineCount: s.isOn)
            case 1:
                self.delegate?.wrapLinesConfigurationDidChange(wrapLines: s.isOn)
            default:
                break
            }
        }
        
        s.addAction(action, for: .valueChanged)
        return s
    }
    
    override func defaultsKey(forIndexPath indexPath: IndexPath) -> String {
        switch (indexPath.section, indexPath.row) {
        case (1, 0):
            return "TextEditorShowLineCount"
        case (1, 1):
            return "TextEditorWrapLines"
        default:
            fatalError()
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
    
    override func tableView(_ tableView: UITableView, shouldHighlightRowAt indexPath: IndexPath) -> Bool {
        return indexPath.section == 2 || (indexPath.section, indexPath.row) == (0, 0)
    }
    
    func setColor(_ color: UIColor, forIndexPath indexPath: IndexPath) {
        switch (indexPath.section, indexPath.row) {
        case (2, 0):
            theme.textColor = CodableColor(color)
            self.delegate?.themeDidChange(to: theme)
        case (2, 1):
            let codableColor = CodableColor(color)
            theme.textEditorBackgroundColor = codableColor
            self.delegate?.didChangeEditorBackground(to: codableColor)
        default:
            break
        }
        
        tableView.reloadRows(at: [indexPath], with: .none)
    }
    
    override func colorPickerViewControllerDidFinish(_ viewController: UIColorPickerViewController) {
        guard let selectedIndexPath = selectedIndexPath else {
            return
        }
        setColor(viewController.selectedColor, forIndexPath: selectedIndexPath)
    }
    
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch section {
        case 0:
            return "Fonts"
        case 1:
            return "Lines"
        case 2:
            return "Colors"
        default:
            return nil
        }
    }
}

extension TextEditorThemeSettingsViewController: UIFontPickerViewControllerDelegate {
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
    func didChangeEditorBackground(to color: CodableColor)
}
