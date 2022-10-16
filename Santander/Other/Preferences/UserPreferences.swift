//
//  UserPreferences.swift
//  Santander
//
//  Created by Serena on 22/06/2022
//


import UIKit

/// Contains user preferences used in the Application
enum UserPreferences {
    @Storage(key: "UseLargeNavTitles", defaultValue: true)
    static var useLargeNavigationTitles: Bool
    
    /// Bookmarked paths saved by the user, stored as Data.
    /// see URL.bookmarkData
    @Storage(key: "BookmarksData", defaultValue: [])
    static private var _bookmarksData: [Data]
    
    /// Bookmarked paths by saved the user
    static var bookmarks: Set<URL> {
        get {
            var dataArr = self._bookmarksData
            let arr = dataArr.compactMap { data in
                var isStale: Bool = false
                let url = try? URL(resolvingBookmarkData: data, bookmarkDataIsStale: &isStale)
                
                // replace if stale
                if isStale, let indx = dataArr.firstIndex(of: data), let urlData = try? url?.bookmarkData() {
                    dataArr[indx] = urlData
                    self._bookmarksData = dataArr
                }
                
                return url
            }
            
            return Set(arr)
        }
        
        set {
            _bookmarksData = newValue.compactMap { url in
                try? url.bookmarkData()
            }
        }
    }
    
    @Storage(key: "AlwaysShowSearchBar", defaultValue: true)
    static var alwaysShowSearchBar: Bool
    
    @Storage(key: "ShowInfoButton", defaultValue: false)
    static var showInfoButton: Bool
    
    @Storage(key: "LastOpenedPath", defaultValue: nil)
    static var lastOpenedPath: String?
    
    @Storage(key: "UseLastOpenedPathWhenLaunching", defaultValue: true)
    static var useLastOpenedPathWhenLaunching: Bool
    
    @Storage(key: "UserPreferredLaunchPath", defaultValue: nil)
    static var userPreferredLaunchPath: String?
    
    @Storage(key: "TextEditorWrapLines", defaultValue: true)
    static var wrapLines: Bool 
    
    @Storage(key: "TextEditorShowLineCount", defaultValue: true)
    static var showLineCount: Bool 
    
    @Storage(key: "TextEditorUseCharacterPairs", defaultValue: true)
    static var useCharacterPairs: Bool
    
    /// The amount of seconds in the go forward / go backward buttons in the `AudioPlayerViewController`
    @Storage(key: "AudioVCSkipDuration", defaultValue: 15)
    static var skipDuration: Int
    
    /// The speed of the audio in the `AudioPlayerViewController`
    @Storage(key: "AudioVCSpeed", defaultValue: 1)
    static var audioVCSpeed: Float
    
    /// Whether or not to display files whose name starts with a dot
    @Storage(key: "displayHiddenFiles", defaultValue: true)
    static var displayHiddenFiles: Bool
    
    /// The user interface style (dark, light, system) which the user choses to use
    @Storage(key: "userIntefaceStyle", defaultValue: UIUserInterfaceStyle.unspecified.rawValue)
    static var preferredInterfaceStyle: Int
    
    @Storage(key: "userPreferredTableViewStyle", defaultValue: UITableView.Style.insetGrouped.rawValue)
    static var preferredTableViewStyle: Int
    
    @Storage(key: "FontViewerFontSize", defaultValue: 30)
    static var fontViewerFontSize: CGFloat
    
    @Storage(key: "AssetCatalogControllerLayoutMode", defaultValue: AssetCatalogViewController.LayoutMode.horizantal.rawValue)
    static var assetCatalogControllerLayoutMode: Int
    
    @CodableStorage(key: "PathGroups", defaultValue: [.default], didChange: { groups in
        NotificationCenter.default.post(name: .pathGroupsDidChange, object: groups)
    })
    static var pathGroups: [PathGroup]
    
    /// The path to launch upon opening the program,
    /// if this is nil, use `URL.root` instead.
    static var launchPath: String? {
        useLastOpenedPathWhenLaunching ? lastOpenedPath : userPreferredLaunchPath
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
    
    static let `default` = PathGroup(name: "Default", paths: [.root])
}
