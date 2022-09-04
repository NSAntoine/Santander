//
//  ImageMetadata.swift
//  Santander
//
//  Created by Serena on 24/08/2022.
//

import Foundation
import ImageIO
import CoreLocation

// warning: tons of `[String: Any]` usage ahead.

/// A Class containing metadata of an image at a specified URL
class ImageMetadata {
    let pixelWidth: Int?
    let pixelHeight: Int?
    
    var location: ImageLocation
    let exifInfo: ImageExifInfo?
    let cameraInfo: ImageCameraInfo?
    let dateTimeTaken: Date?
    
    /// The dictionary containing all values
    var dictionary: [String: Any]
    
    func setProperties(toDictionary newDict: [String: Any], forFileURL fileURL: URL) -> Bool {
        guard let imageSource = CGImageSourceCreateWithURL(fileURL as CFURL, nil),
              let type = CGImageSourceGetType(imageSource),
              let dest = CGImageDestinationCreateWithURL(fileURL as CFURL, type, 1, nil)
        else {
            return false
        }
        
        CGImageDestinationAddImageFromSource(dest, imageSource, 0, newDict as CFDictionary)
        
        if CGImageDestinationFinalize(dest) {
            self.dictionary = newDict
            return true
        } else {
            return false
        }
    }
    
    convenience init?(fileURL: URL) {
        guard let imageSource = CGImageSourceCreateWithURL(fileURL as CFURL, nil),
              let dict = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil) as? [String: Any] else {
            return nil
        }
        
        self.init(dictionary: dict)
    }
    
    init(dictionary dict: [String: Any]) {
        
        self.pixelWidth = dict[kCGImagePropertyPixelWidth as String] as? Int
        self.pixelHeight = dict[kCGImagePropertyPixelHeight as String] as? Int
        
        if let exifDict = dict[kCGImagePropertyExifDictionary as String] as? [String: Any] {
            self.exifInfo = ImageExifInfo(exifDict: exifDict)
        } else {
            self.exifInfo = nil
        }
        
        if let gpsDict = dict[kCGImagePropertyGPSDictionary as String] as? [String: Any] {
            let lat = gpsDict[kCGImagePropertyGPSLatitude as String] as? CLLocationDegrees
            let long = gpsDict[kCGImagePropertyGPSLongitude as String] as? CLLocationDegrees
            self.location = ImageLocation(lat: lat, long: long)
        } else {
            self.location = ImageLocation(lat: nil, long: nil)
        }
        
        if let tiffDict = dict[kCGImagePropertyTIFFDictionary as String] as? [String: Any] {
            self.cameraInfo = ImageCameraInfo(tiffDictionary: tiffDict)
            
            if let dateTime = tiffDict[kCGImagePropertyTIFFDateTime as String] as? String {
                self.dateTimeTaken = DateFormatter.EXIFDateFormatter.date(from: dateTime)
            } else {
                self.dateTimeTaken = nil
            }
            
        } else {
            self.cameraInfo = nil
            self.dateTimeTaken = nil
        }
        
        self.dictionary = dict
//        print(dict)
    }
}

struct ImageLocation {
    var lat: CLLocationDegrees?
    var long: CLLocationDegrees?
    
    var coordinate: CLLocationCoordinate2D? {
        guard let lat = lat, let long = long else {
            return nil
        }
        
        return CLLocationCoordinate2D(latitude: lat, longitude: long)
    }
}

/// Contains the information about the image's camera.
struct ImageCameraInfo {
    let manufacturer: String?
    let model: String?
    let softwareVersion: String?
    
    init(tiffDictionary: [String: Any]) {
        self.manufacturer = tiffDictionary[kCGImagePropertyTIFFMake as String] as? String
        self.model = tiffDictionary[kCGImagePropertyTIFFModel as String] as? String
        self.softwareVersion = tiffDictionary[kCGImagePropertyTIFFSoftware as String] as? String
    }
}

struct ImageExifInfo {
    let apertureValue: Double?
    let brightnessValue: Double?
    let lensModel: String?
    let lensManufacturer: String?
    
    init(exifDict: [String: Any]) {
        self.apertureValue = exifDict[kCGImagePropertyExifApertureValue as String] as? Double
        self.brightnessValue = exifDict[kCGImagePropertyExifBrightnessValue as String] as? Double
        self.lensModel = exifDict[kCGImagePropertyExifLensModel as String] as? String
        self.lensManufacturer = exifDict[kCGImagePropertyExifLensMake as String] as? String
    }
}
