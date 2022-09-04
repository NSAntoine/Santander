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
    
    func application(forDataContainerURL dataContainerURL: URL) -> LSApplicationProxy? {
        return allApps.first { app in
            app.dataContainerURL() == dataContainerURL
        }
    }
    
    func deleteApp(_ app: LSApplicationProxy) throws {
        let errorPointer: NSErrorPointer = nil
        let didSucceed = LSApplicationWorkspace.default().uninstallApplication(app.applicationIdentifier(), withOptions: nil, error: errorPointer, usingBlock: nil)
        if let error = errorPointer?.pointee {
            throw error
        }
        
        guard didSucceed else {
            throw Errors.unableToUninstallApplication(appBundleID: app.applicationIdentifier())
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
        case unableToUninstallApplication(appBundleID: String)
        
        var errorDescription: String? {
            switch self {
            case .unableToOpenApplication(let bundleID):
                return "Unable to open Application with Bundle ID \(bundleID)"
            case .unableToUninstallApplication(let bundleID):
                return "Unable to delete Application with Bundle ID \(bundleID)"
            }
        }
    }
}
