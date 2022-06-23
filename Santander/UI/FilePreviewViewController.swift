//
//  FilePreviewViewController.swift
//  Santander
//
//  Created by Serena on 23/06/2022
//
	


import QuickLook

class FilePreviewDataSource: QLPreviewControllerDataSource {
    func numberOfPreviewItems(in controller: QLPreviewController) -> Int {
        return 1
    }
    
    func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> QLPreviewItem {
        return fileURL as QLPreviewItem
    }
    
    let fileURL: URL
    
    init(fileURL: URL) {
        self.fileURL = fileURL
    }
}
