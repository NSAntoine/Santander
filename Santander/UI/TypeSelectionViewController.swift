//
//  TypeSelectionViewController.swift
//  Santander
//
//  Created by Serena on 01/07/2022
//
	

import UIKit
import UniformTypeIdentifiers

/// A View Controller to select a UTT Type
class TypesSelectionViewController: UITableViewController, UISearchBarDelegate {
    let allTypes: [[UTType]] = UTType.allTypes()
    
    /// The types, filtred by the user search
    var filteredTypes: [UTType] {
        guard let text = navigationItem.searchController?.searchBar.text else {
            return []
        }
        
        return allTypes.flatMap { $0 }.filter { type in
            type.localizedDescription?.localizedCaseInsensitiveContains(text) ?? false ||
            type.preferredFilenameExtension?.localizedCaseInsensitiveContains(text) ?? false
        }
    }
    
    var selectedTypes: [UTType] = [] {
        didSet {
            // if the types are empty
            // disable the 'Done' button
            self.navigationItem.rightBarButtonItem?.isEnabled = !selectedTypes.isEmpty
        }
    }
    
    var collapsedSections: Set<Int> = []
    var isSearching: Bool = false
    
    typealias DismissHandler = (([UTType]) -> Void)
    
    /// The action to execute once the ViewController is dismissed
    var dismissHandler: DismissHandler
    
    init(style: UITableView.Style = .insetGrouped, onDismisAction: @escaping DismissHandler) {
        self.dismissHandler = onDismisAction
        
        super.init(style: style)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.title = "Types"
        let searchController = UISearchController(searchResultsController: nil)
        searchController.searchBar.delegate = self
        self.navigationItem.searchController = searchController
        self.navigationItem.hidesSearchBarWhenScrolling = false
        
#if compiler(>=5.7)
        if #available(iOS 16.0, *) {
            // .inline looks frustrating on iPad
            self.navigationItem.preferredSearchBarPlacement = .stacked
        }
#endif
        
        self.navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(doneDismiss))
        self.navigationItem.rightBarButtonItem?.isEnabled = !selectedTypes.isEmpty
        
        self.navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(cancel))
    }
    
    
    required init?(coder: NSCoder) {
        fatalError()
    }
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        if self.isSearching {
            return 1
        }
        
        return allTypes.count
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if self.collapsedSections.contains(section) {
            return 0
        }
        
        if self.isSearching {
            return filteredTypes.count
        } else {
            return allTypes[section].count
        }
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let type = self.type(forIndexPath: indexPath)
        
        let cell = UITableViewCell()
        var conf = cell.defaultContentConfiguration()
        conf.text = type.localizedDescription
        cell.contentConfiguration = conf
        cell.accessoryType = selectedTypes.contains(type) ? .checkmark : .none
        return cell
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let type = self.type(forIndexPath: indexPath)
        
        if selectedTypes.contains(type) {
            selectedTypes.removeAll { $0 == type }
        } else {
            selectedTypes.append(type)
        }
        
        tableView.reloadRows(at: [indexPath], with: .fade)
    }
    
    func headerTitle(forSection section: Int) -> String? {
        switch section {
        case 0: return self.isSearching ? "Results" : "Generic"
        case 1: return "Audio"
        case 2: return "Programming"
        case 3: return "Archive"
        case 4: return "Image"
        case 5: return "Document"
        case 6: return "Executable"
        case 7: return "System"
        default: return nil
        }
    }
    
    override func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        return sectionHeaderWithButton(action: #selector(sectionButtonClicked(_:)), sectionTag: section, titleText: headerTitle(forSection: section)) { button in
            button.setImage(UIImage(systemName: "chevron.down"), for: .normal)
        }
    }
    
    @objc
    func sectionButtonClicked(_ sender: UIButton) {
        let section = sender.tag
        let isCollapsing: Bool = !(self.collapsedSections.contains(section))
        let newImageToSet = isCollapsing ? "chevron.forward" : "chevron.down"

        let animationOptions: UIView.AnimationOptions = isCollapsing ? .transitionFlipFromLeft : .transitionFlipFromRight

        UIView.transition(with: sender, duration: 0.3, options: animationOptions) {
            sender.setImage(UIImage(systemName: newImageToSet), for: .normal)
        }

        if isCollapsing {
            // Need to capture the index paths *before inserting* when collapsing
            let indexPaths: [IndexPath] = self.indexPaths(forSection: section)
            collapsedSections.insert(section)
            tableView.deleteRows(at: indexPaths, with: .fade)
        } else {
            collapsedSections.remove(section)
            tableView.insertRows(at: self.indexPaths(forSection: section), with: .fade)
        }

    }
    
    override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return 40
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        self.dismissHandler(selectedTypes)
    }
    
    @objc
    func doneDismiss() {
        self.dismiss(animated: true)
    }
    
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        isSearching = !searchText.isEmpty
        self.tableView.reloadData()
    }
    
    func searchBarCancelButtonClicked(_ searchBar: UISearchBar) {
        // When cancelling, set the text to be empty, so that it displays all items
        self.searchBar(searchBar, textDidChange: "")
    }
    
    @objc
    func cancel() {
        self.selectedTypes = []
        self.dismiss(animated: true)
    }
    
    func type(forIndexPath indexPath: IndexPath) -> UTType {
        if self.isSearching {
            return filteredTypes[indexPath.row]
        } else {
            return allTypes[indexPath.section][indexPath.row]
        }
    }
}
