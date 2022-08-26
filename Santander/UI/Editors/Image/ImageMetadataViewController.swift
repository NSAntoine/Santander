//
//  ImageMetadataViewController.swift
//  Santander
//
//  Created by Serena on 24/08/2022.
//

import UIKit

/// A ViewController displaying the metadata of an image
class ImageMetadataViewController: UITableViewController {
    var metadata: ImageMetadata
    let fileURL: URL
    
    init(metadata: ImageMetadata, fileURL: URL) {
        self.metadata = metadata
        self.fileURL = fileURL
        
        super.init(style: .userPreferred)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 4
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch section {
        case 0, 1: return 3
        case 2, 3: return 2
        default: fatalError()
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.title = "Metadata"
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: .value1, reuseIdentifier: nil)
        var conf = cell.defaultContentConfiguration()
        
        defer {
            cell.contentConfiguration = conf
        }
        
        switch (indexPath.section, indexPath.row) {
        case (0, 0):
            conf.text = "Pixel Height"
            conf.secondaryText = metadata.pixelHeight?.description ?? "N/A"
        case (0, 1):
            conf.text = "Pixel Width"
            conf.secondaryText = metadata.pixelWidth?.description ?? "N/A"
        case (0, 2):
            let datePicker = UIDatePicker()
            if let dateTaken = metadata.dateTimeTaken {
                datePicker.setDate(dateTaken, animated: true)
            }
            
            let action = UIAction {
                self.setNewDate(withDatePicker: datePicker)
            }
            
            // add the action for .editingDidEnd
            // and not for valueChanged
            // in order to avoid writing to the file a lot more than needed
            datePicker.addAction(action, for: .editingDidEnd)
            return cellWithView(datePicker, text: "Date", rightAnchorConstant: -5)
        case (1, 0):
            conf.text = "Camera Model"
            conf.secondaryText = metadata.cameraInfo?.model ?? "N/A"
        case (1, 1):
            conf.text = "Camera Manufacturer"
            conf.secondaryText = metadata.cameraInfo?.manufacturer ?? "N/A"
        case (1, 2):
            conf.text = "Camera Software"
            conf.secondaryText = metadata.cameraInfo?.softwareVersion ?? "N/A"
        case (2, 0):
            conf.text = "Lens Model"
            conf.secondaryText = metadata.exifInfo?.lensModel ?? "N/A"
        case (2, 1):
            conf.text = "Lens Manufacturer"
            conf.secondaryText = metadata.exifInfo?.lensManufacturer ?? "N/A"
        case (3, 0):
            conf.text = "Latitude"
            conf.secondaryText = metadata.location.lat?.description ?? "N/A"
        case (3, 1):
            conf.text = "Longitude"
            conf.secondaryText = metadata.location.long?.description ?? "N/A"
        default:
            break
        }
        
        return cell
    }
    
    override func tableView(_ tableView: UITableView, shouldHighlightRowAt indexPath: IndexPath) -> Bool {
        return false
    }
    
    func headerTitle(forSection section: Int) -> String {
        switch section {
        case 0:
            return "General"
        case 1:
            return "Camera"
        case 2:
            return "Lens"
        case 3:
            return "Location"
        default:
            fatalError()
        }
    }
    
    /// Called when the date is changed on the date picker
    func setNewDate(withDatePicker datePicker: UIDatePicker) {
        let exifFormattedDate = DateFormatter.EXIFDateFormatter.string(from: datePicker.date)
        let iptcFormattedDate = DateFormatter.IPTCDateFormatter.string(from: datePicker.date)
        var copy = metadata.dictionary
        
        // modify tiff dictionary
        var tiffDictionary = (copy[kCGImagePropertyTIFFDictionary as String] as? [String: Any]) ?? [:]
        tiffDictionary[kCGImagePropertyTIFFDateTime as String] = exifFormattedDate
        
        // modify EXIF dictionary
        var exifDictionary = (copy[kCGImagePropertyExifDictionary as String] as? [String: Any]) ?? [:]
        exifDictionary[kCGImagePropertyExifDateTimeOriginal as String] = exifFormattedDate
        exifDictionary[kCGImagePropertyExifDateTimeDigitized as String] = exifFormattedDate
        
        // modify IPTC dictionary
        var iptcDictionary = (copy[kCGImagePropertyIPTCDictionary as String] as? [String: Any]) ?? [:]
        iptcDictionary[kCGImagePropertyIPTCDateCreated as String] = iptcFormattedDate
        
        copy[kCGImagePropertyTIFFDictionary as String] = tiffDictionary
        copy[kCGImagePropertyExifDictionary as String] = exifDictionary
        copy[kCGImagePropertyIPTCDictionary as String] = iptcDictionary
        
        if !metadata.setProperties(toDictionary: copy, forFileURL: fileURL) {
            errorAlert("", title: "Unable to set date of image")
        }
    }
    
    override func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        return sectionHeaderWithButton(sectionTag: section, titleText: headerTitle(forSection: section)) { button in
            guard section == 3 else {
                button.isHidden = true
                return
            }

            let action = UIAction { _ in
                self.presentMapEditor()
            }

            button.setTitle("View", for: .normal)
            button.setTitleColor(.systemBlue, for: .normal)
            button.addAction(action, for: .touchUpInside)
        }
    }
    
    override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return 40
    }
    
    func presentMapEditor() {
        let vc = ImageLocationEditorViewController(metadata: metadata, metadataSenderVC: self, fileURL: fileURL)
        let navVC = UINavigationController(rootViewController: vc)
        navVC.modalPresentationStyle = .fullScreen
        self.present(navVC, animated: true)
    }
}
