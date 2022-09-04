//
//  FontInformationViewController.swift
//  Santander
//
//  Created by Serena on 03/09/2022.
//

import UIKit

/// A ViewController displaying information about a Font
class FontInformationViewController: UITableViewController {
    let font: UIFont
    let ctFont: CTFont
    let fontName: String
    
    init(font: UIFont) {
        self.font = font
        self.ctFont = font as CTFont
        self.fontName = CTFontCopyAttribute(ctFont, kCTFontDisplayNameAttribute) as? String ?? font.fontName
        
        super.init(style: .userPreferred)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // a label, with the font set as the font being viewed
        // and the text set as the font name
        let fontLabel = UILabel()
        fontLabel.text = fontName
        fontLabel.font = font.withSize(30)
        
        navigationItem.titleView = fontLabel
    }
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 2
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch section {
        case 0:
            return 6
        case 1:
            return 3
        default:
            fatalError()
        }
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: .value1, reuseIdentifier: nil)
        var conf = cell.defaultContentConfiguration()
        defer {
            cell.contentConfiguration = conf
        }
        
        switch (indexPath.section, indexPath.row) {
        case (0, 0):
            conf.text = "Full name"
            conf.secondaryText = fontName
        case (0, 1):
            conf.text = "Family name"
            conf.secondaryText = font.familyName
        case (0, 2):
            conf.text = "PostScript name"
            conf.secondaryText = font.fontDescriptor.postscriptName
        case (0, 3):
            conf.text = "Style"
            conf.secondaryText = CTFontCopyAttribute(ctFont, kCTFontStyleNameAttribute) as? String ?? "N/A"
        case (0, 4):
            conf.text = "Enabled"
            if let isEnabled = CTFontCopyAttribute(ctFont, kCTFontEnabledAttribute) as? Bool {
                conf.secondaryText = isEnabled ? "Yes" : "No"
            } else {
                conf.secondaryText = "N/A"
            }
        case (0, 5):
            conf.text = "URL"
            let url = CTFontCopyAttribute(ctFont, kCTFontURLAttribute) as? URL
            conf.secondaryText = url?.path ?? "N/A"
        case (1, 0):
            conf.text = "Designer"
            conf.secondaryText = CTFontCopyName(ctFont, kCTFontDesignerNameKey) as? String ?? "N/A"
        case (1, 1):
            conf.text = "Manufacturer"
            conf.secondaryText = CTFontCopyName(ctFont, kCTFontManufacturerNameKey) as? String ?? "N/A"
        case (1, 2):
            conf.text = "Version"
            conf.secondaryText = CTFontCopyName(ctFont, kCTFontVersionNameKey) as? String ?? "N/A"
        default:
            fatalError("Unhandled indexPath: \(indexPath)")
        }
        
        return cell
    }
    
    override func tableView(_ tableView: UITableView, shouldHighlightRowAt indexPath: IndexPath) -> Bool {
        return false
    }
}
