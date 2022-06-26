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
    
    static var showInfoButton: Bool {
        get {
            return UserDefaults.standard.bool(forKey: "ShowInfoButton")
        }
        
        set {
            UserDefaults.standard.set(newValue, forKey: "ShowInfoButton")
        }
    }
    
    static var pathGroups: [PathGroup] {
        get {
            guard let data = UserDefaults.standard.data(forKey: "UserPathGroups"),
                  let decoded = try? JSONDecoder().decode([PathGroup].self, from: data), !decoded.isEmpty else {
                return PathGroup.defaults
            }

            return decoded
        }
        
        set {
            guard let encoded = try? JSONEncoder().encode(newValue) else {
                return
            }
            
            UserDefaults.standard.set(encoded, forKey: "UserPathGroups")
            NotificationCenter.default.post(name: .pathGroupsDidChange, object: nil)
        }
    }
}

/// A Group containing paths
struct PathGroup: Codable, Hashable {
    let name: String
    var paths: [URL]
    
    static var defaults: [PathGroup] {
        return [
            PathGroup(name: "Default", paths: [.root])
        ]
    }
}
