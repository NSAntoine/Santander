//
//  CarWrapper.swift
//  Santander
//
//  Created by Serena on 16/09/2022
//


import UIKit
import UniformTypeIdentifiers
import CoreUIBridge

typealias RenditionCollection = [(type: RenditionType, renditions: [Rendition])]

class AssetCatalogWrapper {
    static let shared = AssetCatalogWrapper()
    
    func renditions(forCarArchive url: URL) throws -> (CUICatalog, RenditionCollection) {
        let catalog = try CUICatalog(url: url)
        var dict: [RenditionType: [Rendition]] = [:]
        
        catalog.enumerateNamedLookups { lookup in
            let rend = Rendition(lookup)
            if var existing = dict[rend.type] {
                existing.append(rend)
                dict[rend.type] = existing
            } else {
                dict[rend.type] = [rend]
            }
        }
        
        var arr = RenditionCollection()
        for (key, value) in dict {
            arr.append((key, value))
        }
        
        // sort by Alphabetical order
        arr = arr.sorted { first, second in
            return first.type.description < second.type.description
        }
        
        return (catalog, arr)
    }
}

/// Represents a Core UI rendition
class Rendition: Hashable {
    
    /// the ThemeSubtype constant used to identify renditions
    /// classified as `macCatalyst`
    /// see `RenditionIdiom`'s init
    static let macCatalystSubtype = 32401
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(cuiRend)
        hasher.combine(namedLookup)
        hasher.combine(type)
    }
    
    static func == (lhs: Rendition, rhs: Rendition) -> Bool {
        return lhs.cuiRend == rhs.cuiRend && lhs.namedLookup == rhs.namedLookup && lhs.type == rhs.type
    }
    
    let cuiRend: CUIThemeRendition
    let namedLookup: CUINamedLookup
    let type: RenditionType
    let name: String
    
    lazy var preview: RenditionPreview? = RenditionPreview(self)
    lazy var image: CGImage? = _getImage()
    
    func _getImage() -> CGImage? {
        if let cgImage = cuiRend.uncroppedImage()?.takeUnretainedValue() {
            return cgImage
        } else if type == .pdf,
                  let pdfCgImage = cuiRend.createImageFromPDFRendition(withScale: UIScreen.main.scale)?.takeUnretainedValue() {
            return pdfCgImage
        }
        
        return nil
    }
    
    init(_ namedLookup: CUINamedLookup) {
        let rendition = namedLookup.rendition
        self.cuiRend = rendition
        self.namedLookup = namedLookup
        self.type = .init(namedLookup: namedLookup)
        
        self.name = type == .icon ? cuiRend.name() : namedLookup.name
    }
    
    func makeDragItem() -> UIDragItem? {
        guard let cgImage = self.image else { return nil }
        
        let image = UIImage(cgImage: cgImage)
        let itemProvider = NSItemProvider(object: image)
        let dragItem = UIDragItem(itemProvider: itemProvider)
        dragItem.localObject = image
        
        return dragItem
    }
    
    /// The idiom, aka the platform target, of a Rendition
    enum Idiom: CustomStringConvertible {
        /// All platforms.
        case universal
        
        case iphone
        case ipad
        case tv
        case watch
        case carPlay
        case macCatalyst
        
        /// This seems to be for App Store related renditions.
        case marketing
        
        init?(_ keyList: CUIRenditionKey) {
            if keyList.themeSubtype == Rendition.macCatalystSubtype {
                self = .macCatalyst
                return
            }
            
            switch keyList.themeIdiom {
            case 0:
                self = .universal
            case 1:
                self = .iphone
            case 2:
                self = .ipad
            case 3:
                self = .tv
            case 4:
                self = .carPlay
            case 5:
                self = .watch
            case 6:
                self = .marketing
            default:
                return nil
            }
        }
        
        var description: String {
            switch self {
            case .universal:
                return "Universal"
            case .iphone:
                return "iPhone"
            case .ipad:
                return "iPad"
            case .tv:
                return "TV"
            case .watch:
                return "Watch"
            case .carPlay:
                return "CarPlay"
            case .macCatalyst:
                return "Mac Catalyst"
            case .marketing:
                return "Marketing"
            }
        }
    }
    
    enum DisplayGamut: Int64, Hashable, CustomStringConvertible {
        case sRGB = 0
        case p3 = 1
        
        init?(_ key: CUIRenditionKey) {
            self.init(rawValue: key.themeDisplayGamut)
        }
        
        var description: String {
            switch self {
            case .sRGB:
                return "SRGB"
            case .p3:
                return "Display P3"
            }
        }
    }
    
    enum Appearance: Int64, CustomStringConvertible {
        case any = 0
        case dark = 1
        case highContrast = 2
        case highConstrastDark = 3
        case light = 4
        case highConstrastLight = 5
        
        init?(_ key: CUIRenditionKey) {
            self.init(rawValue: key.themeAppearance)
        }
        
        var description: String {
            switch self {
            case .any:
                return "Any"
            case .dark:
                return "Dark"
            case .light:
                return "Light"
            case .highContrast:
                return "High Constrast"
            case .highConstrastDark:
                return "High Contrast Dark"
            case .highConstrastLight:
                return "High Constrast Light"
            }
        }
    }
}

enum RenditionType: Hashable, CustomStringConvertible {
    case image, icon, imageSet, multiSizeImageSet
    case pdf
    case color
    case svg
    case rawData
    case unknown
    
    init(namedLookup: CUINamedLookup) {
        let className = String(describing: namedLookup.rendition.classForCoder)
        
        switch className {
        case "_CUIRawPixelRendition": // non PNG images? lmao
            self = .image
        case "_CUIThemePixelRendition", "_CUIInternalLinkRendition":
            let key = namedLookup.key
            
            switch key.themeElement {
            case 85 where key.themePart == 220 :
                self = .icon
            case 9:
                self = .imageSet
            default:
                self = .image
            }
        case "_CUIThemePDFRendition":
            self = .pdf
        case "_CUIThemeColorRendition":
            self = .color
        case "_CUIThemeSVGRendition":
            self = .svg
        case "_CUIThemeMultisizeImageSetRendition":
            self = .multiSizeImageSet
        case "_CUIRawDataRendition":
            self = .rawData
        default:
            self = .unknown
        }
    }
    
    var description: String {
        switch self {
        case .image:
            return "Image"
        case .icon:
            return "Icon"
        case .imageSet:
            return "Image Set"
        case .multiSizeImageSet:
            return "Multisize Image Set"
        case .pdf:
            return "PDF"
        case .color:
            return "Color"
        case .svg:
            return "SVG (Vector)"
        case .rawData:
            return "Raw Data"
        case .unknown:
            return "Unknown"
        }
    }
    
    var isEditable: Bool {
        switch self {
        case .image, .icon:
            return true
        default:
            return false
        }
    }
    
}

enum RenditionPreview: Hashable {
    case color(CGColor)
    case image(CGImage)
    
    var uiView: UIView {
        var view = UIView()
        switch self {
        case .color(let cgColor):
            view.backgroundColor = UIColor(cgColor: cgColor)
        case .image(let cgImage):
            view = UIImageView(image: UIImage(cgImage: cgImage))
            view.clipsToBounds = true
        }
        
        return view
    }
    
    init?(_ rendition: Rendition) {
        if let cgColor = rendition.cuiRend.cgColor()?.takeUnretainedValue() {
            self = .color(cgColor)
        } else if let image = rendition.image {
            self = .image(image)
        } else {
            return nil
        }
    }
    
}

extension CUICatalog {
    /// Removes an item, and returns a new, updated catalog for the file URL
    func removeItem(_ rendition: Rendition, fileURL: URL) throws {
        let keyStore = try keyStore(forFileURL: fileURL)
        guard let data = _themeStore().convertRenditionKey(toKeyData: rendition.cuiRend.key()) else {
            throw _Errors.unableToAccessItemData
        }
        
        keyStore.removeAsset(forKey: data)
        try writekeyStore(keyStore, to: fileURL)
    }
    
    func editItem(_ item: Rendition, fileURL: URL, to newValue: RenditionPreview) throws {
        guard let keyStore = CUIMutableCommonAssetStorage(path: fileURL.path, forWriting: true) else {
            throw _Errors.unableToAccessCatalogFile(fileURL: fileURL)
        }
        
        
        switch newValue {
        case .color(_):
            return
        default: break
        }
        //todo: get this working for colors
        // refactored from https://github.com/joey-gm/Aphrodite/blob/a334eb6a7c4863897723c968bd7a083ae1df75b9/Aphrodite/Models/AssetCatalog.swift#L181
        var rendition = item.cuiRend
        let assetStorage = keyStore
        let themeStore = _themeStore()
        
        let isInternalLink: Bool = rendition.isInternalLink()
        let linkRect: CGRect = rendition._destinationFrame()
        guard let keyList = rendition.linkingToRendition()?.keyList() else {
            throw _Errors.failedToEditItem()
        }
        
        var carKey = themeStore.convertRenditionKey(toKeyData: keyList)
        if isInternalLink {
            let keyList = rendition.linkingToRendition()?.keyList()
            carKey = themeStore.convertRenditionKey(toKeyData: keyList)
            rendition = CUIThemeRendition(csiData: assetStorage.asset(forKey: carKey!), forKey: keyList)
        }
        
        guard let carKey = carKey else {
            throw _Errors.failedToEditItem(lineFailed: #line)
        }
        
        let unslicedSize: CGSize = rendition.unslicedSize()
        let renditionLayout = rendition.type == 0 ? Int16(rendition.subtype) : Int16(rendition.type)
        guard let generator = CSIGenerator(canvasSize: unslicedSize, sliceCount: 1, layout: renditionLayout),
              let wrapper = CSIBitmapWrapper(pixelWidth: UInt32(unslicedSize.width),
                                             pixelHeight: UInt32(unslicedSize.height))
        else {
            throw _Errors.failedToEditItem()
        }
        
        let context = Unmanaged<CGContext>.fromOpaque(wrapper.bitmapContext()).takeUnretainedValue()
        
        switch newValue {
        case .image(let newImage):
            if isInternalLink {
                if let existingImage = rendition.unslicedImage()?.takeUnretainedValue() {
                    context.draw(existingImage, in: CGRect(origin: .zero, size: unslicedSize))
                    context.clear(linkRect.insetBy(dx: -2, dy: -2)) // clear the original image and the 2px broader
                }
                
                context.draw(newImage, in: linkRect)
            } else {
                context.draw(newImage, in: CGRect(origin: .zero, size: unslicedSize))
            }
        case .color(_):
            break
//            context.clear(linkRect.insetBy(dx: -2, dy: -2))
//            context.setFillColor(newColor)
        }
        
        //Add Bitmap Wrapper and Set Rendition Properties
        generator.addBitmap(wrapper)
        generator.addSliceRect(rendition._destinationFrame())
        let flags = rendition.renditionFlags()?.pointee
        generator.name                          = rendition.name()
        generator.blendMode                     = rendition.blendMode
        generator.colorSpaceID                  = Int16(rendition.colorSpaceID())
        generator.exifOrientation               = rendition.exifOrientation
        generator.opacity                       = rendition.opacity
        generator.scaleFactor                   = UInt32(rendition.scale())
        generator.templateRenderingMode         = rendition.templateRenderingMode()
        generator.utiType                       = rendition.utiType()
        generator.isVectorBased                 = rendition.isVectorBased()
        generator.excludedFromContrastFilter    = Bool(truncating: (flags?.isExcludedFromContrastFilter ?? 0) as NSNumber)
        
        guard let csiRep = generator.csiRepresentation(withCompression: true) else {
            throw _Errors.failedToEditItem()
        }
        
        assetStorage.setAsset(csiRep, forKey: carKey)
        
        try writekeyStore(keyStore, to: fileURL)
    }
    
    // so we don't have to repeat code above
    private func keyStore(forFileURL fileURL: URL) throws -> CUIMutableCommonAssetStorage {
        guard let keyStore = CUIMutableCommonAssetStorage(path: fileURL.path, forWriting: true) else {
            throw _Errors.unableToAccessCatalogFile(fileURL: fileURL)
        }
        
        return keyStore
    }
    
    private func writekeyStore(_ keyStore: CUIMutableCommonAssetStorage, to fileURL: URL) throws {
        guard keyStore.writeToDisk(compact: true) else {
            throw _Errors.unableToWriteToCatalogFile(fileURL: fileURL)
        }
    }
    
    private enum _Errors: Error, LocalizedError {
        case unableToAccessCatalogFile(fileURL: URL)
        case unableToWriteToCatalogFile(fileURL: URL)
        
        // for when `convertRenditionKey` fails
        case unableToAccessItemData
        
        case failedToEditItem(lineFailed: Int = #line)
        
        var errorDescription: String? {
            switch self {
            case .unableToAccessCatalogFile(let fileURL):
                return "Unable to read catalog file \(fileURL.lastPathComponent)"
            case .unableToWriteToCatalogFile(let fileURL):
                return "Unable to write to catalog file \(fileURL.lastPathComponent)"
            case .unableToAccessItemData:
                return "Unable to access data of item"
            case .failedToEditItem(let lineFailed):
                #if DEBUG
                return "Failed to edit item, failed at line \(lineFailed)"
                #else
                return "Failed to edit item, unknown cause. Blame CoreUI!"
                #endif
            }
        }
    }
    
}
