//
//  FileEditorType.swift
//  Santander
//
//  Created by Serena on 16/08/2022.
//

import UIKit

struct FileEditor {
    let type: FileEditorType
    let viewController: UIViewController
    
    static func preferred(forURL url: URL) -> FileEditor? {
        if let audio = FileEditorType.audio.viewController(forPath: url) {
            return FileEditor(type: .audio, viewController: audio)
        } else {
            let ext = url.pathExtension
            if (ext == "plist" || ext == "xml"), let plistVc = FileEditorType.propertyList.viewController(forPath: url) {
                return FileEditor(type: .propertyList, viewController: plistVc)
            }
            
            if let textEditorVc = FileEditorType.text.viewController(forPath: url) {
                return FileEditor(type: .text, viewController: textEditorVc)
            }
            
            return nil
        }
    }
    
    static func allEditors(forURL url: URL) -> [FileEditor] {
        return FileEditorType.allCases.compactMap { type in
            guard let vc = type.viewController(forPath: url) else {
                return nil
            }
            return FileEditor(type: type, viewController: vc)
        }
    }
}

enum FileEditorType: CustomStringConvertible, CaseIterable {
    case audio, propertyList, text
    
    func viewController(forPath path: URL) -> UIViewController? {
        switch self {
        case .audio:
            return try? AudioPlayerViewController(fileURL: path)
        case .propertyList:
            return PropertyListViewController(fileURL: path, parent: .root)
        case .text:
            return try? TextFileEditorViewController(fileURL: path)
        }
    }
    
    var description: String {
        switch self {
        case .audio:
            return "Audio Player"
        case .propertyList:
            return "Property List Editor"
        case .text:
            return "Text Editor"
        }
    }
}
