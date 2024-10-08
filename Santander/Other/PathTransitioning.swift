//
//  PathTransitioning.swift
//  Santander
//
//  Created by Antoine on 12/10/2022
//


import Foundation

/// A Protocol describing an object which can move from it's current path to another
protocol PathTransitioning {
    func goToPath(path: Path)
}
