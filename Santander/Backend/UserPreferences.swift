//
//  UserPreferences.swift
//  Santander
//
//  Created by Serena on 22/06/2022
//


import Foundation

enum UserPreferences {
    static var useLargeNavigationTitles: Bool {
        get {
            UserDefaults.standard.object(forKey: "UseLargeNavTitles") as? Bool ?? true
        }
        
        set {
            UserDefaults.standard.set(newValue, forKey: "UseLargeNavTitles")
        }
    }
    
    static var favouritePaths: [String] {
        get {
            UserDefaults.standard.stringArray(forKey: "FavPaths") ?? []
        }
        
        set {
            UserDefaults.standard.set(newValue, forKey: "FavPaths")
        }
    }
    
    static var alwaysShowSearchBar: Bool {
        get {
            UserDefaults.standard.bool(forKey: "AlwaysShowSearchBar")
        }
        
        set {
            UserDefaults.standard.set(newValue, forKey: "AlwaysShowSearchBar")
        }
    }
    
    static var usePlainStyleTableView: Bool {
        get {
            UserDefaults.standard.object(forKey: "usePlainStyleTableView") as? Bool ?? true
        }
        
        set {
            UserDefaults.standard.set(newValue, forKey: "usePlainStyleTableView")
        }
    }
}
