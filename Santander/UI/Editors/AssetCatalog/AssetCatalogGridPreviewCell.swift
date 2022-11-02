//
//  AssetCatalogGridPreviewCell.swift
//  Santander
//
//  Created by Serena on 08/10/2022
//


import UIKit
import AssetCatalogWrapper

fileprivate extension CACornerMask {
    static func alongEdge(_ edge: CGRectEdge) -> CACornerMask {
        switch edge {
        case .maxXEdge: return [.layerMaxXMinYCorner, .layerMaxXMaxYCorner]
        case .maxYEdge: return [.layerMinXMaxYCorner, .layerMaxXMaxYCorner]
        case .minXEdge: return [.layerMinXMinYCorner, .layerMinXMaxYCorner]
        case .minYEdge: return [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        }
    }
}

class AssetCatalogGridPreviewCell: UICollectionViewCell {
    var rendition: Rendition!
    var previewView: UIView!
    
    func configure() {
        var constraintCompletely: Bool = true
        if let preview = rendition.representation {
            previewView = preview.uiView
        } else {
            let noPreviewLabel = UILabel()
            noPreviewLabel.text = "No Preview."
            noPreviewLabel.textColor = .secondaryLabel
            previewView = noPreviewLabel
            constraintCompletely = false
        }
        
        previewView.clipsToBounds = true
        previewView.contentMode = .scaleAspectFit
        previewView.translatesAutoresizingMaskIntoConstraints = false
        
        contentView.addSubview(previewView)
        contentView.layer.cornerCurve = .continuous
        contentView.layer.cornerRadius = 12.0
        
        layer.shadowOpacity = 0.2
        layer.shadowRadius = 6.0
        
        pushCornerPropertiesToChildren()
        
        if constraintCompletely {
            previewView.constraintCompletely(to: contentView.layoutMarginsGuide)
        } else {
            NSLayoutConstraint.activate([
                previewView.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
                previewView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor)
            ])
        }
    }
    
    override var reuseIdentifier: String? {
        rendition?.name
    }
    
    func pushCornerPropertiesToChildren() {
        previewView.layer.maskedCorners = contentView.layer.maskedCorners.union(.alongEdge(.maxYEdge))
        previewView.layer.cornerRadius = contentView.layer.cornerRadius
        previewView.layer.cornerCurve = contentView.layer.cornerCurve
    }
}
