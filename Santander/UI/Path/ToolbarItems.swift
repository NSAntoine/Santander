//
//  ToolbarItems.swift
//  Santander
//
//  Created by Serena on 04/08/2022.
//

import UIKit


extension SubPathsTableViewController: AudioPlayerToolbarDelegate {
    
    @objc
    func setupOrUpdateToolbar() {
        
        let trashAction = UIAction {
            let confirmationController = UIAlertController(title: "Are you sure you want to delete \(self.selectedItems.count) item(s)?", message: nil, preferredStyle: .alert)
            
            let deleteAction = UIAlertAction(title: "Delete", style: .destructive) { _ in
                
                // if we fail to delete one or multiple paths, save them to this dictionary to display them
                var failedDict: [String: Error] = [:]
                for item in self.selectedItems {
                    do {
                        try FSOperation.perform(.removeItem, url: item)
                    } catch {
                        failedDict[item.lastPathComponent] = error
                    }
                }
                
                if !failedDict.isEmpty {
                    var message: String = ""
                    for (item, error) in failedDict {
                        message.append("\(item): \(error.localizedDescription)\n")
                    }
                    self.errorAlert(message, title: "Failed to delete \(failedDict.count) item(s)")
                }
            }
            
            confirmationController.addAction(.cancel())
            confirmationController.addAction(deleteAction)
            self.present(confirmationController, animated: true)
        }
        
        let trash = UIBarButtonItem(systemItem: .trash, primaryAction: trashAction)
        trash.tintColor = .systemRed
        
        let shareAction = UIAction {
            self.presentActivityVC(forItems: self.selectedItems)
        }
        
        let share = UIBarButtonItem(image: UIImage(systemName: "square.and.arrow.up"), primaryAction: shareAction)
        let moreItems = UIBarButtonItem(image: UIImage(systemName: "ellipsis.circle"), menu: makeToolbarMoreItemsMenu())
        let items = [trash, .flexibleSpace(), share, .flexibleSpace(), moreItems].map { item in
            item.isEnabled = !selectedItems.isEmpty
            return item
        }
        
        self.toolbarItems = items
        self.navigationController?.setToolbarHidden(false, animated: true)
        self.navigationController?.toolbar.viewWithTag(100)?.removeFromSuperview() // if necessary
    }
    
    @objc
    func hideToolbarItems() {
        self.toolbarItems = []
        self.navigationController?.setToolbarHidden(true, animated: true)
        
        // since we're hiding the toolbar items, (copy, move, etc)
        // lets see if we can bring the audio toolbar back if possible
        setupAudioToolbarIfPossible()
    }
    
    fileprivate func makeToolbarMoreItemsMenu() -> UIMenu {
        let moveAction = UIAction(title: "Move", image: UIImage(systemName: "arrow.right")) { _ in
            let vc = PathOperationViewController(paths: self.selectedItems, operationType: .move)
            self.present(UINavigationController(rootViewController: vc), animated: true)
        }
        
        let copyAction = UIAction(title: "Copy", image: UIImage(systemName: "doc.on.doc")) { _ in
            let vc = PathOperationViewController(paths: self.selectedItems, operationType: .copy)
            self.present(UINavigationController(rootViewController: vc), animated: true)
        }
        
        let symlinkAction = UIAction(title: "Alias", image: UIImage(systemName: "link")) { _ in
            let vc = PathOperationViewController(paths: self.selectedItems, operationType: .symlink)
            self.present(UINavigationController(rootViewController: vc), animated: true)
        }
        
        var children = [symlinkAction, moveAction, copyAction]
        if let currentPath = currentPath {
            let compressAction = UIAction(title: "Compress", image: UIImage(systemName: "archivebox")) { _ in
                do {
                    let zipFilePath = currentPath.appendingPathComponent("Archive.zip")
                    try Compression.shared.zipFiles(paths: self.selectedItems, zipFilePath: zipFilePath)
                } catch {
                    self.errorAlert(error, title: "Unable to compress items")
                }
            }
            
            children.insert(compressAction, at: 0)
        }
        
        return UIMenu(children: children)
    }
    
    /// The button which says "Select all" or "Deselect all" when in edit mode
    @objc
    func setLeftBarSelectionButtonItem() {
        if !isEditing {
            navigationItem.leftBarButtonItem = nil
            return
        }
        
        let contents = self.contents // in order to not keep triggering the getter
        let allItemsSelected = selectedItems.count == contents.count
        let action = UIAction {
            for index in contents.indices {
                if !allItemsSelected {
                    self.tableView.selectRow(at: IndexPath(row: index, section: 0), animated: true, scrollPosition: .none)
                } else {
                    self.tableView.deselectRow(at: IndexPath(row: index, section: 0), animated: true)
                }
            }
            
            self.selectedItems = allItemsSelected ? [] : contents // why do i have to do this? welp! it works
            self.setLeftBarSelectionButtonItem()
        }
        
        self.navigationItem.leftBarButtonItem = UIBarButtonItem(title: allItemsSelected ? "Deselect All" : "Select All", primaryAction: action)
        setupOrUpdateToolbar()
    }
    
    func setupAudioToolbarIfPossible() {
        guard let audioPlayerController = audioPlayerController, let toolbar = navigationController?.toolbar else {
            return
        }
        
        navigationController?.setToolbarHidden(false, animated: true)
        
        let blurView = UIVisualEffectView(effect: UIBlurEffect(style: .regular))
        blurView.frame = toolbar.bounds
        
        let audioToolbarView = AudioPlayerToolbarView(audioPlayerController, frame: blurView.bounds)
        audioToolbarView.delegate = self
        blurView.contentView.addSubview(audioToolbarView)
        blurView.tag = 100
        blurView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(toolbarAudioPreviewWasTapped)))
        toolbar.addSubview(blurView)
    }
    
    @objc
    func toolbarAudioPreviewWasTapped() {
        guard let vc = audioPlayerController else {
            return
        }
        
        // TERRIBLE WORKAROUND: - if the user goes to another ViewController
        // self.present simply won't work
        // so we just present from the keyWindow lol
        UIApplication.shared.sceneKeyWindow?.rootViewController?.present(UINavigationController(rootViewController: vc), animated: true)
    }
    
    func audioToolbarDidClickCancelButton(_ toolbar: AudioPlayerToolbarView) {
        // Why do we need to use rootNav?
        // for the same reason we must use the terrible workaround in `toolbarAudioPreviewWasTapped`
        let rootNav = UIApplication.shared.sceneKeyWindow?.rootViewController as? UINavigationController
        rootNav?.toolbar?.viewWithTag(100)?.removeFromSuperview()
        rootNav?.setToolbarHidden(true, animated: true)
        
        toolbar.audioPlayerController.player.stop()
        toolbar.audioPlayerController.removeFromSystemMediaPlayer()
        self.audioPlayerController = nil
    }
}
