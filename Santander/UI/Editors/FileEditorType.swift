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
        guard let data = try? Data(contentsOf: url) else {
            return nil
        }
        
        if let audio = FileEditorType.audio.viewController(forPath: url, data: data) {
            return FileEditor(type: .audio, viewController: audio)
        }
        
        if let imageVC = FileEditorType.image.viewController(forPath: url, data: data) {
            return FileEditor(type: .image, viewController: imageVC)
        }
        
        if let plistVc = FileEditorType.propertyList.viewController(forPath: url, data: data) {
            return FileEditor(type: .propertyList, viewController: plistVc)
        }
        
        if url.pathExtension == "json", let jsonVC = FileEditorType.json.viewController(forPath: url, data: data) {
            return FileEditor(type: .json, viewController: jsonVC)
        }
        
        if let textEditorVc = FileEditorType.text.viewController(forPath: url, data: data) {
            return FileEditor(type: .text, viewController: textEditorVc)
        }
        
        return nil
    }
    
    static func allEditors(forURL url: URL) -> [FileEditor] {
        guard let data = try? Data(contentsOf: url) else {
            return []
        }
        
        return FileEditorType.allCases.compactMap { type in
            guard let vc = type.viewController(forPath: url, data: data) else {
                return nil
            }
            return FileEditor(type: type, viewController: vc)
        }
    }
}

enum FileEditorType: CustomStringConvertible, CaseIterable {
    case audio, image, propertyList, json, text
    
    /// Returns the view controller to be used for the file editor type
    /// the Data parameter is used so that, when looping over all editor types,
    /// it tries to get the data for only one time
    func viewController(forPath path: URL, data: Data) -> UIViewController? {
        switch self {
        case .audio:
            return try? AudioPlayerViewController(fileURL: path, data: data)
        case .propertyList:
            return SerializedDocumentViewController(type: .plist(format: nil), fileURL: path, data: data, canEdit: true)
        case .json:
            return SerializedDocumentViewController(type: .json, fileURL: path, data: data, canEdit: true)
        case .text:
            guard let stringContents = String(data: data, encoding: .utf8) else {
                return nil
            }
            
            return TextFileEditorViewController(fileURL: path, contents: stringContents)
        case .image:
            guard let image = UIImage(data: data) else {
                return nil
            }
            
            return ImageFileViewController(fileURL: path, image: image)
        }
    }
    
    var description: String {
        switch self {
        case .audio:
            return "Audio Player"
        case .image:
            return "Image Viewer"
        case .propertyList:
            return "Property List Viewer"
        case .json:
            return "JSON Viewer"
        case .text:
            return "Text Editor"
        }
    }
    
    var presentAsFullScreen: Bool {
        switch self {
        case .audio, .text, .image:
            return true
        case .propertyList, .json:
            return false
        }
    }
}
