//
//  DiffableDataSourceItem.swift
//  Santander
//
//  Created by Serena on 04/11/2022
//


import UIKit

/// Describes a generic item for diffable data sources,
/// either being a section or an item
enum DiffableDataSourceItem<Section: Hashable, Item: Hashable> {
    case section(Section)
    case item(Item)
    
    static func fromItems(_ items: [Item]) -> [DiffableDataSourceItem] {
        return items.map { item in
            return .item(item)
        }
    }
}

extension DiffableDataSourceItem: Hashable {}
