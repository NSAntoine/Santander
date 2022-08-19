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
            if let plistVc = FileEditorType.propertyList.viewController(forPath: url) {
                return FileEditor(type: .propertyList, viewController: plistVc)
            }
            
            if url.pathExtension == "json", let jsonVC = FileEditorType.json.viewController(forPath: url) {
                return FileEditor(type: .json, viewController: jsonVC)
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
    case audio, propertyList, json, text
    
    func viewController(forPath path: URL) -> UIViewController? {
        switch self {
        case .audio:
            return try? AudioPlayerViewController(fileURL: path)
        case .propertyList:
            return SerializedDocumentViewController(type: .plist(format: nil), fileURL: path, canEdit: true)
        case .json:
            return SerializedDocumentViewController(type: .json, fileURL: path, canEdit: true)
        case .text:
            return try? TextFileEditorViewController(fileURL: path)
        }
    }
    
    var description: String {
        switch self {
        case .audio:
            return "Audio Player"
        case .propertyList:
            return "Property List Viewer"
        case .json:
            return "JSON Viewer"
        case .text:
            return "Text Editor"
        }
    }
}
