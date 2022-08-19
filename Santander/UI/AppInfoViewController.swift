//
//  AppInfoViewController.swift
//  Santander
//
//  Created by Serena on 15/08/2022.
//

import UIKit
import LaunchServicesPrivate

/// A ViewController to display information about an app
class AppInfoViewController: UITableViewController {
    let app: LSApplicationProxy
    // used to go to a path if selected in the current view controller
    let subPathsSender: SubPathsTableViewController
    
    init(style: UITableView.Style, app: LSApplicationProxy, subPathsSender: SubPathsTableViewController) {
        self.app = app
        self.subPathsSender = subPathsSender
        super.init(style: style)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        navigationItem.titleView = UIImageView(image: ApplicationsManager.shared.icon(forApplication: app))
    }
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 5
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch section {
        case 0:
            return app.claimedURLSchemes.isEmpty ? 3 : 4
        case 1:
            return 2
        case 2:
            return 4
        case 3:
            return 2
        case 4:
            return 1
        default:
            fatalError("Unknown section! \(section)")
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
            conf.text = "Name"
            conf.secondaryText = app.localizedName()
        case (0, 1):
            conf.text = "Bundle ID"
            conf.secondaryText = app.applicationIdentifier()
        case (0, 2):
            conf.text = "App type"
            conf.secondaryText = app.applicationType
        case (0, 3):
            conf.text = "URL schemes"
            conf.secondaryText = app.claimedURLSchemes.joined(separator: ", ")
        case (1, 0):
            conf.text = "Team ID"
            conf.secondaryText = app.teamID
        case (1, 1):
            conf.text = "Entitlements"
            cell.accessoryType = .disclosureIndicator
        case (2, 0):
            conf.text = "Deletable"
            conf.secondaryText = app.isDeletable ? "Yes" : "No"
        case (2, 1):
            conf.text = "Beta app"
            conf.secondaryText = app.isBetaApp ? "Yes" : "No"
        case (2, 2):
            conf.text = "Restricted"
            conf.secondaryText = app.isRestricted ? "Yes" : "No"
        case (2, 3):
            conf.text = "Containerized"
            conf.secondaryText = app.isContainerized ? "Yes" : "No"
        case (3, 0):
            conf.text = "Container URL"
            conf.secondaryText = app.containerURL().path
        case (3, 1):
            conf.text = "Bundle URL"
            conf.secondaryText = app.bundleURL().path
        case (4, 0):
            conf.text = "Open"
            conf.textProperties.color = .systemBlue
        default:
            fatalError("Unknown indexPath: \(indexPath)")
        }
        
        return cell
    }
    
    override func tableView(_ tableView: UITableView, shouldHighlightRowAt indexPath: IndexPath) -> Bool {
        switch indexPath.section {
        case 3, 4:
            return true
        default:
            return (indexPath.section, indexPath.row) == (1, 1) // entitlements
        }
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        switch (indexPath.section, indexPath.row) {
        case (1, 1):
            var dict: SerializedDocumentViewController.SerializedDictionaryType = [:]
            for (key, value) in app.entitlements {
                dict[key] = .init(item: value)
            }
            
            let vc = SerializedDocumentViewController(dictionary: dict, type: .plist(format: nil), title: "Entitlements", canEdit: false)
            self.navigationController?.pushViewController(vc, animated: true)
        case (3, 0):
            dismissAndGoToURL(app.containerURL())
        case (3, 1):
            dismissAndGoToURL(app.bundleURL())
        case (4, 0):
            do {
                try ApplicationsManager.shared.openApp(app)
            } catch {
                self.errorAlert(error, title: "Unable to open \(app.localizedName())")
            }
        default:
            break
        }
    }
    
    func dismissAndGoToURL(_ url: URL) {
        self.dismiss(animated: true)
        
        subPathsSender.goToPath(path: url)
    }
}
