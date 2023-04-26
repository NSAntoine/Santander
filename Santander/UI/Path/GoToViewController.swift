//
//  GoToViewController.swift
//  Santander
//
//  Created by Antoine on 22/04/2023.
//  

import UIKit

class GoToView: UIView {
    let xButton = UIButton()
    let searchField = UITextField()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func setup() {
        layer.cornerRadius = 10
        layer.masksToBounds = true
        
        let visualEffectView = UIVisualEffectView(effect: UIBlurEffect(style: .systemThickMaterial))
        visualEffectView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(visualEffectView)
        visualEffectView.constraintCompletely(to: self)
        
        let glassImage = UIImageView(image: UIImage(systemName: "magnifyingglass")?.applyingSymbolConfiguration(UIImage.SymbolConfiguration(pointSize: 30))?.withTintColor(.systemGray, renderingMode: .alwaysOriginal))
        glassImage.translatesAutoresizingMaskIntoConstraints = false
        glassImage.contentScaleFactor = 1.0
        visualEffectView.contentView.addSubview(glassImage)
        
        searchField.tintColor = .white
        searchField.font = .systemFont(ofSize: 30)
        searchField.translatesAutoresizingMaskIntoConstraints = false
        searchField.placeholder = "Search"
        visualEffectView.contentView.addSubview(searchField)
        
        xButton.translatesAutoresizingMaskIntoConstraints = false
//        xButton.setImage(UIImage(systemName: "xmark.circle.fill")?.withTintColor(.systemGray, renderingMode: .alwaysOriginal), for: .normal)
        xButton.setImage(UIImage(systemName: "xmark.circle.fill")?.applyingSymbolConfiguration(UIImage.SymbolConfiguration(pointSize: 30))?.withTintColor(.systemGray, renderingMode: .alwaysOriginal), for: .normal)
        visualEffectView.contentView.addSubview(xButton)
        
        let stackView = UIStackView(arrangedSubviews: [glassImage, searchField, xButton])
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.spacing = 5
        stackView.distribution = .fillProportionally
        visualEffectView.contentView.addSubview(stackView)
        NSLayoutConstraint.activate([
            stackView.leadingAnchor.constraint(equalTo: visualEffectView.contentView.layoutMarginsGuide.leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: visualEffectView.contentView.layoutMarginsGuide.trailingAnchor),
            stackView.topAnchor.constraint(equalTo: visualEffectView.contentView.layoutMarginsGuide.topAnchor, constant: 10)
        ])
        /*
        NSLayoutConstraint.activate([
            glassImage.leadingAnchor.constraint(equalTo: visualEffectView.contentView.layoutMarginsGuide.leadingAnchor),
            glassImage.topAnchor.constraint(equalTo: visualEffectView.contentView.layoutMarginsGuide.topAnchor, constant: 10),
//            glassImage.widthAnchor.constraint(equalToConstant: 30),
            
            searchField.leadingAnchor.constraint(equalTo: glassImage.trailingAnchor, constant: 5),
            searchField.centerYAnchor.constraint(equalTo: glassImage.centerYAnchor),
            
            xButton.trailingAnchor.constraint(equalTo: visualEffectView.contentView.layoutMarginsGuide.trailingAnchor),
            xButton.leadingAnchor.constraint(equalTo: visualEffectView.contentView.layoutMarginsGuide.trailingAnchor, constant: -10),
            xButton.centerYAnchor.constraint(equalTo: searchField.centerYAnchor),
            
            searchField.trailingAnchor.constraint(equalTo: xButton.leadingAnchor),
        ])
        */
        searchField.becomeFirstResponder()
    }
}
