//
//  ApplicationsManager.swift
//  Santander
//
//  Created by Serena on 15/08/2022.
//

import UIKit
import LaunchServicesPrivate

/// A Swift Wrapper to manage Applications
struct ApplicationsManager {
    let allApps: [LSApplicationProxy]
    static let shared = ApplicationsManager(allApps: LSApplicationWorkspace.default().allInstalledApplications())
    
    func application(forContainerURL containerURL: URL) -> LSApplicationProxy? {
        return allApps.first { app in
            app.containerURL() == containerURL
        }
    }
    
    func application(forBundleURL bundleURL: URL) -> LSApplicationProxy? {
        return allApps.first { app in
            app.bundleURL() == bundleURL
        }
    }
    
    func icon(forApplication app: LSApplicationProxy, scale: CGFloat = UIScreen.main.scale) -> UIImage {
        return ._applicationIconImage(forBundleIdentifier: app.applicationIdentifier(), format: 1, scale: scale)
    }
    
    func openApp(_ app: LSApplicationProxy) throws {
        guard LSApplicationWorkspace.default().openApplication(withBundleID: app.applicationIdentifier()) else {
            throw Errors.unableToOpenApplication(appBundleID: app.applicationIdentifier())
        }
    }
    
    enum Errors: Error, LocalizedError {
        case unableToOpenApplication(appBundleID: String)
        
        var errorDescription: String? {
            switch self {
            case .unableToOpenApplication(let bundleID):
                return "Unable to open Application with Bundle ID \(bundleID)"
            }
        }
    }
}
