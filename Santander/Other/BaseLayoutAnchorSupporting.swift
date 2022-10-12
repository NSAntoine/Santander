//
//  BaseLayoutAnchorSupporting.swift
//  Santander
//
//  Created by Serena on 08/10/2022
//
	

import UIKit

/// A Protocol defining the basic layout anchors of an object, such as  UIView or a UI
protocol BaseLayoutAnchorSupporting {
    var leadingAnchor: NSLayoutXAxisAnchor { get }
    var trailingAnchor: NSLayoutXAxisAnchor { get }
    var topAnchor: NSLayoutYAxisAnchor { get }
    var bottomAnchor: NSLayoutYAxisAnchor { get }
}

extension UILayoutGuide: BaseLayoutAnchorSupporting {}
extension UIView: BaseLayoutAnchorSupporting {
    /// Activates constraints which completely cover the other view with the current view
    func constraintCompletely(to otherView: BaseLayoutAnchorSupporting) {
        NSLayoutConstraint.activate([
            self.leadingAnchor.constraint(equalTo: otherView.leadingAnchor),
            self.trailingAnchor.constraint(equalTo: otherView.trailingAnchor),
            self.topAnchor.constraint(equalTo: otherView.topAnchor),
            self.bottomAnchor.constraint(equalTo: otherView.bottomAnchor)
        ])
    }
}
