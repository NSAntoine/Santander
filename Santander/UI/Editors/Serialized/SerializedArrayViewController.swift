//
//  SerializedArrayViewController.swift
//  Santander
//
//  Created by Serena on 18/08/2022.
//

import UIKit

class SerializedArrayViewController: UITableViewController {
    let array: NSArray
    
    init(style: UITableView.Style, array: NSArray, title: String) {
        self.array = array
        
        super.init(style: style)
        self.title = title
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return array.count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell()
        var conf = cell.defaultContentConfiguration()
        conf.text = SerializedDocumentType(item: array[indexPath.row]).description
        cell.contentConfiguration = conf
        return cell
    }
    
    override func tableView(_ tableView: UITableView, shouldHighlightRowAt indexPath: IndexPath) -> Bool {
        return false
    }
}
