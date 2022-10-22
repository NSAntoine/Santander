//
//  SceneDelegate.swift
//  Santander
//
//  Created by Serena on 21/06/2022
//


import UIKit

class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    
    var window: UIWindow?
    var visibleSubPathsVc: SubPathsTableViewController? {
        (window?.rootViewController as? UINavigationController)?.visibleViewController as? SubPathsTableViewController
    }
    
    func performShortcut(_ shortcut: UIApplicationShortcutItem) {
        switch shortcut.type {
        case "com.serena.santander.bookmarks":
            let vc = UINavigationController(rootViewController: SubPathsTableViewController.bookmarks())
            window?.rootViewController?.present(vc, animated: true)
        default:
            break
        }
    }
    
    func windowScene(_ windowScene: UIWindowScene,performActionFor shortcutItem: UIApplicationShortcutItem, completionHandler: @escaping (Bool) -> Void) {
        self.performShortcut(shortcutItem)
        completionHandler(true)
    }
    
    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        // Use this method to optionally configure and attach the UIWindow `window` to the provided UIWindowScene `scene`.
        // If using a storyboard, the `window` property will automatically be initialized and attached to the scene.
        // This delegate does not imply the connecting scene or session are new (see `application:configurationForConnectingSceneSession` instead).
        guard let windowScene = (scene as? UIWindowScene) else { return }
        
        let subPathsVC: PathTransitioning
        let window = UIWindow(windowScene: windowScene)
        if UIDevice.current.isiPad {
            let splitVC = UISplitViewController(style: .doubleColumn)
            let vc = PathSidebarListViewController()
            subPathsVC = vc
            splitVC.setViewController(vc, for: .primary)
            window.rootViewController = splitVC
        } else {
            let vc = SubPathsTableViewController(style: .userPreferred, path: .root)
            subPathsVC = vc
            window.rootViewController = UINavigationController(rootViewController: vc)
        }
        
        DispatchQueue.main.async {
            window.tintColor = UserPreferences.appTintColor.uiColor
            window.overrideUserInterfaceStyle = UIUserInterfaceStyle(rawValue: UserPreferences.preferredInterfaceStyle) ?? .unspecified
        }
        
        self.window = window
        
        // Needed on iPad so that the SplitViewController displays no matter orientation
        (window.rootViewController as? UISplitViewController)?.show(.primary)
        if let launchPath = UserPreferences.launchPath,
            FileManager.default.fileExists(atPath: launchPath) {
            subPathsVC.goToPath(path: URL(fileURLWithPath: launchPath))
        }
        
        window.makeKeyAndVisible()
        // handle incoming URLs
        self.scene(scene, openURLContexts: connectionOptions.urlContexts)
        // handle possible shortcut clicked
        if let shortcut = connectionOptions.shortcutItem {
            self.performShortcut(shortcut)
        }
    }
    
    func sceneDidDisconnect(_ scene: UIScene) {
        // Called as the scene is being released by the system.
        // This occurs shortly after the scene enters the background, or when its session is discarded.
        // Release any resources associated with this scene that can be re-created the next time the scene connects.
        // The scene may re-connect later, as its session was not necessarily discarded (see `application:didDiscardSceneSessions` instead).
    }
    
    func sceneDidBecomeActive(_ scene: UIScene) {
        // Called when the scene has moved from an inactive state to an active state.
        // Use this method to restart any tasks that were paused (or not yet started) when the scene was inactive.
    }
    
    func sceneWillResignActive(_ scene: UIScene) {
        // Called when the scene will move from an active state to an inactive state.
        // This may occur due to temporary interruptions (ex. an incoming phone call).
    }
    
    func sceneWillEnterForeground(_ scene: UIScene) {
        // Called as the scene transitions from the background to the foreground.
        // Use this method to undo the changes made on entering the background.
    }
    
    func sceneDidEnterBackground(_ scene: UIScene) {
        // Called as the scene transitions from the foreground to the background.
        // Use this method to save data, release shared resources, and store enough scene-specific state information
        // to restore the scene back to its current state.
    }
    
    
    // Path is being imported
    func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
        // map them to file URLs instead of `santander://` URLs
        let urls = URLContexts.map { ctx in
            URL(fileURLWithPath: ctx.url.path)
        }
        guard !urls.isEmpty else {
            return
        }
  
        let alertController = UIAlertController(title: "URL(s) being imported to app, would you like to copy it to another path?", message: nil, preferredStyle: .alert)
        let copyAction = UIAlertAction(title: "Copy Path", style: .default) { _ in
            self.window?.rootViewController?.present(UINavigationController(rootViewController: PathOperationViewController(paths: urls, operationType: .import)), animated: true)
        }
        
        alertController.addAction(copyAction)
        // if there's just one item, display option to go it's path
        if urls.count == 1 {
            let viewItemAction = UIAlertAction(title: "View item", style: .default) { _ in
                let item = urls[0]
                let itemParentPath = item.deletingLastPathComponent()
                let rootVC = self.window?.rootViewController as? UINavigationController
                let vcToPush = SubPathsTableViewController(path: itemParentPath)
                rootVC?.pushViewController(vcToPush, animated: true) {
                    if let indx = vcToPush.contents.firstIndex(of: item) {
                        let indexPath = IndexPath(row: indx, section: 0)
                        vcToPush.tableView.scrollToRow(at: indexPath, at: .middle, animated: true)
                        vcToPush.tableView.selectRow(at: indexPath, animated: true, scrollPosition: .middle)
                    }
                }
            }
            
            alertController.addAction(viewItemAction)
        }
        
        alertController.addAction(.cancel())
        window?.rootViewController?.present(alertController, animated: true)
        
    }
}

fileprivate extension UINavigationController {
    func pushViewController(_ viewController: UIViewController, animated: Bool, completion: @escaping (() -> Void)) {
        pushViewController(viewController, animated: animated)
        
        guard animated, let coordinator = transitionCoordinator else {
            completion()
            return
        }
        
        coordinator.animate(alongsideTransition: nil) { _ in completion() }
    }
}
