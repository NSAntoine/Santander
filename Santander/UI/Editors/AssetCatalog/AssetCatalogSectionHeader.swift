//
//  AssetCatalogSectionHeader.swift
//  Santander
//
//  Created by Serena on 21/09/2022
//


import UIKit
import AssetCatalogWrapper

class AssetCatalogSectionHeader: UICollectionReusableView {
    let stackView = UIStackView()
    
    let titleLabel = UILabel()
    let subtitleLabel = UILabel()
    
    func configure(withSection section: RenditionType, snapshot: NSDiffableDataSourceSnapshot<RenditionType, Rendition>, sender: AssetCatalogViewController) {
        // The titleLabel's text is the name of the section
        // And the subtitleLabel's text is the amount of items in the section
        // ie, the UI would look something like
        // "Color"
        // "6 Items"
        
        titleLabel.text = section.description
        titleLabel.font = .preferredFont(forTextStyle: .title3)
        
        subtitleLabel.text = "\(snapshot.itemIdentifiers(inSection: section).count) Items"
        subtitleLabel.textColor = .secondaryLabel
        subtitleLabel.font = .preferredFont(forTextStyle: .caption1)
        
        stackView.addArrangedSubview(titleLabel)
        stackView.addArrangedSubview(subtitleLabel)
        
        stackView.axis = .vertical
        stackView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stackView)
        
        let guide = layoutMarginsGuide
        NSLayoutConstraint.activate([
            stackView.centerYAnchor.constraint(equalTo: guide.centerYAnchor),
            stackView.leadingAnchor.constraint(equalTo: guide.leadingAnchor)
        ])
    }
}
