//
//  ImageFileViewController.swift
//  Santander
//
//  Created by Serena on 21/08/2022.
//

import UIKit
import PDFKit // Hacky workaround, but PDFView is the best way to display the image due to the built in scroll view support

/// The ViewController displaying an image
class ImageFileViewController: UIViewController {
    let fileURL: URL
    let image: UIImage
    var metadata: ImageMetadata?
    
    init(fileURL: URL, image: UIImage) {
        self.fileURL = fileURL
        self.image = image
        
        super.init(nibName: nil, bundle: nil)
    }
    
    convenience init?(fileURL: URL) {
        guard let image = UIImage(contentsOfFile: fileURL.path) else {
            return nil
        }
        
        self.init(fileURL: fileURL, image: image)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // note: - don't move this to the init,
        // because we only want to assign this once the view loaded
        self.metadata = ImageMetadata(fileURL: fileURL)
        
        title = fileURL.lastPathComponent
        view.backgroundColor = .systemBackground
        
        let doneAction = UIAction { _ in
            self.dismiss(animated: true)
        }
        
        
        let doneButton = UIBarButtonItem(systemItem: .done, primaryAction: doneAction)
        let infoButton = UIBarButtonItem()
        
        if let metadata = self.metadata {
            let infoAction = UIAction { _ in
                let vc = ImageMetadataViewController(metadata: metadata, fileURL: self.fileURL)
                self.present(UINavigationController(rootViewController: vc), animated: true)
            }
            
            infoButton.primaryAction = infoAction
        } else {
            infoButton.isEnabled = false
        }
        
        // when assinging the primaryAction of the button, the image becomes nil?
        // so we assign it here, rather than at initialization of infoButton
        infoButton.image = UIImage(systemName: "info.circle")
        
        navigationItem.rightBarButtonItem = doneButton
        navigationItem.leftBarButtonItem = infoButton
        
        if let pdfPage = PDFPage(image: image) {
            let pdfView = PDFView(frame: self.view.bounds)
            pdfView.displayDirection = .vertical
            pdfView.displayMode = .singlePage
            pdfView.backgroundColor = .systemBackground
            
            let pdfDoc = PDFDocument()
            pdfDoc.insert(pdfPage, at: 0)
            
            pdfView.document = pdfDoc
            pdfView.autoScales = true
            pdfView.minScaleFactor = pdfView.scaleFactorForSizeToFit
            
            self.view = pdfView
        } else {
            setupFailedLabel()
        }
        
        configureNavigationBarToNormal()
        setupToolbar()
    }
    
    func setupFailedLabel() {
        let failedLabel = UILabel()
        failedLabel.text = "Failed to display image."
        failedLabel.textColor = .systemGray
        failedLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(failedLabel)
        
        NSLayoutConstraint.activate([
            failedLabel.centerXAnchor.constraint(equalTo: self.view.centerXAnchor),
            failedLabel.centerYAnchor.constraint(equalTo: self.view.centerYAnchor)
        ])
    }
    
    
    func setupToolbar() {
        let shareMenuAction = UIAction {
            self.presentActivityVC(forItems: [self.fileURL])
        }
        
        let shareMenuButton = UIBarButtonItem(image: UIImage(systemName: "square.and.arrow.up"), primaryAction: shareMenuAction)
        self.toolbarItems = [shareMenuButton]
        self.navigationController?.setToolbarHidden(false, animated: true)
    }
}
