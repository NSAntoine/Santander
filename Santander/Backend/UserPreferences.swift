//
//  UserPreferences.swift
//  Santander
//
//  Created by Serena on 22/06/2022
//
	

import Foundation

enum UserPreferences {
    static var useLargeNavigationTitles: Bool = UserDefaults.standard.bool(forKey: "UseLargeNavTitles")
    
    static var favouritePaths: [String] = UserDefaults.standard.stringArray(forKey: "FavPaths") ?? []
}
