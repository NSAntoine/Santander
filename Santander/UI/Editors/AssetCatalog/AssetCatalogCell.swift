//
//  AssetCatalogCell.swift
//  Santander
//
//  Created by Serena on 18/09/2022
//


import UIKit
import AssetCatalogWrapper

class AssetCatalogCell: UICollectionViewCell {
    let nameLabel: UILabel = UILabel()
    let subtitleLabel: UILabel = UILabel()
    lazy var circleView: UIView? = rendition?.preview?.uiView
    var rendition: Rendition?
}

extension AssetCatalogCell {
    func configure() {
        setupShape()
        
        guard let rendition = rendition else { return }
        nameLabel.text = rendition.name
        subtitleLabel.text = makeSubtitleText(forRendition: rendition)
        subtitleLabel.font = .preferredFont(forTextStyle: .caption1)
        subtitleLabel.textColor = .secondaryLabel
        
        let labelsStackView = UIStackView(arrangedSubviews: [nameLabel, subtitleLabel])
        labelsStackView.translatesAutoresizingMaskIntoConstraints = false
        labelsStackView.axis = .vertical
        
        let stackView = UIStackView(arrangedSubviews: [labelsStackView])
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.spacing = 10
        
        contentView.addSubview(stackView)
        let guide = contentView.layoutMarginsGuide
        if let circleView = circleView {
            circleView.layer.cornerRadius = 20
            circleView.layer.cornerCurve = .circular
            circleView.translatesAutoresizingMaskIntoConstraints = false
            stackView.insertArrangedSubview(circleView, at: 0)
            
            NSLayoutConstraint.activate([
                circleView.heightAnchor.constraint(equalTo: guide.heightAnchor),
                circleView.widthAnchor.constraint(equalTo: guide.heightAnchor),
            ])
        }
        
        stackView.constraintCompletely(to: guide)
    }
    
    func makeSubtitleText(forRendition rend: Rendition) -> String {
        return "Scale: \(rend.cuiRend.scale())" // todo: more info?
    }
    
    // IMPORTANT: Don't get rid of this, otherwise cells will start mixing with each other
    // due to each one having the same reuseIdentifier by default..
    override var reuseIdentifier: String? {
        return rendition?.name
    }
    
    func setupShape() {
        var bgConf = UIBackgroundConfiguration.clear()
        bgConf.backgroundColor = .quaternarySystemFill
        bgConf.cornerRadius = 14
        backgroundConfiguration = bgConf
    }
}
