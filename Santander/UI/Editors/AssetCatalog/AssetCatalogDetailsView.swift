//
//  AssetCatalogDetailsView.swift
//  Santander
//
//  Created by Serena on 27/09/2022
//


import UIKit
import CoreUIBridge

#warning("get this working: A view which displays the details of an asset catalog")
class AssetCatalogDetailsView: UIView {
    var catalog: CUICatalog
    
    init(catalog: CUICatalog) {
        self.catalog = catalog
        super.init(frame: .zero)
        
        let testLabel = UILabel()
        testLabel.text = "Hello"
        testLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(testLabel)
        
        NSLayoutConstraint.activate([
            testLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
            testLabel.leadingAnchor.constraint(equalTo: leadingAnchor)
        ])
        
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
}
