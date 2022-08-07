//
//  UserPreferences.swift
//  Santander
//
//  Created by Serena on 22/06/2022
//


import Foundation

/// Contains user preferences used in the Application
enum UserPreferences {
    @Storage(key: "UseLargeNavTitles", defaultValue: true)
    static var useLargeNavigationTitles: Bool
    
    @Storage(key: "FavPaths", defaultValue: [])
    static var favouritePaths: [String]
    
    @Storage(key: "AlwaysShowSearchBar", defaultValue: true)
    static var alwaysShowSearchBar: Bool
    
    @Storage(key: "usePlainStyleTableView", defaultValue: false)
    static var usePlainStyleTableView: Bool
    
    @Storage(key: "ShowInfoButton", defaultValue: false)
    static var showInfoButton: Bool
    
    @Storage(key: "LastOpenedPath", defaultValue: nil)
    static var lastOpenedPath: String?
    
    @Storage(key: "TextEditorWrapLines", defaultValue: true)
    static var wrapLines: Bool 
    
    @Storage(key: "TextEditorShowLineCount", defaultValue: true)
    static var showLineCount: Bool 
    
    /// The amount of seconds in the go forward / go backward buttons in the `AudioPlayerViewController`
    @Storage(key: "AudioVCSkipDuration", defaultValue: 15)
    static var skipDuration: Int
    
    /// The speed of the audio in the `AudioPlayerViewController`
    @Storage(key: "AudioVCSpeed", defaultValue: 1)
    static var audioVCSpeed: Float
    
    @Storage(key: "displayHiddenFiles", defaultValue: true)
    static var displayHiddenFiles: Bool
    
    static var pathGroups: [PathGroup] {
        get {
            guard let data = UserDefaults.standard.data(forKey: "UserPathGroups"),
                  var decoded = try? JSONDecoder().decode([PathGroup].self, from: data),
                    !decoded.isEmpty else {
                // if we can't get the saved path groups - or if they're empty,
                // return the only defaut one
                return [.default]
            }
            
            // Make sure we always have the default group
            if !decoded.contains(.default) {
                decoded.insert(.default, at: 0)
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
    
    @CodableStorage(key: "TextEditorTheme", defaultValue: CodableTheme(), didChange: nil)
    static var textEditorTheme: CodableTheme
    
    @CodableStorage(key: "AppTintColor", defaultValue: CodableColor(.systemBlue), didChange: nil)
    static var appTintColor: CodableColor
}

/// A Group containing paths
struct PathGroup: Codable, Hashable {
    let name: String
    var paths: [URL]
    
    static var `default`: PathGroup {
        return PathGroup(name: "", paths: [.root])
    }
}
