//
//  ImageFileViewController.swift
//  Santander
//
//  Created by Serena on 21/08/2022.
//

import UIKit
import ObjectiveC
import PDFKit // Hacky workaround, but PDFView is the best way to display the image due to the built in scroll view support

/// The ViewController displaying an image
class ImageFileViewController: UIViewController {
    let fileURL: URL
    let image: UIImage
    var metadata: ImageMetadata?
    
    /// The signature of the function used to set the wallpaper
    /// by SpringBoardUIServices
    typealias SetWallpaperFunction = @convention(c) (_: NSDictionary, _: NSDictionary, _: Int, _: Int) -> Int
    
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
        let saveImageAction = UIAction(title: "Save Image") { _ in
            UIImageWriteToSavedPhotosAlbum(self.image, self, #selector(self.didSaveImage(_:error:context:)), nil)
        }
        
        // the places to set the wallpaper, represented by a UIAction
        let setWallpaperActions = WallpaperLoction.allCases.map { location in
            return UIAction(title: location.description) { _ in
                self.setImageAsWallpaper(to: location)
            }
        }
        
        let setAsWallpaperMenu = UIMenu(title: "Set as wallpaper for..", children: setWallpaperActions)
        
        let actionsMenu = UIMenu(children: [saveImageAction, setAsWallpaperMenu])
        self.toolbarItems = [shareMenuButton, .flexibleSpace(), UIBarButtonItem(image: UIImage(systemName: "ellipsis.circle"), menu: actionsMenu)]
        self.navigationController?.setToolbarHidden(false, animated: true)
    }
    
    @objc
    func didSaveImage(_ im: UIImage, error: Error?, context: UnsafeMutableRawPointer?) {
        if let error = error {
            errorAlert(error, title: "Unable to save image to camera roll")
        }
    }
    
    func setImageAsWallpaper(to location: WallpaperLoction) {
        // for SBFWallpaperOptions
        let sbF = dlopen("/System/Library/PrivateFrameworks/SpringBoardFoundation.framework/SpringBoardFoundation", RTLD_LAZY)
        // for SBSUIWallpaperSetImages
        let sbServer = dlopen("/System/Library/PrivateFrameworks/SpringBoardUIServices.framework/SpringBoardUIServices", RTLD_LAZY)
        
        defer {
            dlclose(sbF)
            dlclose(sbServer)
        }
        
        guard let options = NSClassFromString("SBFWallpaperOptions")?.alloc(),
              let pointer = dlsym(sbServer, "SBSUIWallpaperSetImages"),
              let setWallpaperFunc = unsafeBitCast(pointer, to: (SetWallpaperFunction)?.self)
        else {
            errorAlert(nil, title: "Unable to set image as wallpaper")
            return
        }
        
        let imagesDict = [
            "light": image,
            "dark": image
        ]
        
        let optionsDict = [
            "light" : options,
            "dark": options
        ]
        
        let result = setWallpaperFunc(NSDictionary(dictionary: imagesDict), NSDictionary(dictionary: optionsDict), location.rawValue, UIUserInterfaceStyle.dark.rawValue)
        // 1 is success
        if result != 1 {
            errorAlert(nil, title: "Unable to set image as wallpaper")
        }
    }
    
    /// The places where an image can be set as the Wallpaper
    /// The integer values here are passed directly to `SBSUIWallpaperSetImages`
    enum WallpaperLoction: Int, CustomStringConvertible, CaseIterable {
        case lockScreen = 1
        case homeScreen = 2
        case both = 3
        
        var description: String {
            switch self {
            case .lockScreen:
                return "Lock Screen"
            case .homeScreen:
                return "Home Screen"
            case .both:
                return "Both"
            }
        }
    }
}
