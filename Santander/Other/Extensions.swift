//
//  Extensions.swift
//  Santander
//
//  Created by Serena on 21/06/2022
//

// TODO: - Move all of this to other files, with separate files for each extension


import UIKit
import UniformTypeIdentifiers
import LaunchServicesPrivate

extension URL {
    
    func regularFileAllocatedSize() throws -> UInt64 {
        let resourceValues = try self.resourceValues(forKeys: allocatedSizeResourceKeys)
        
        // We only look at regular files.
        guard resourceValues.isRegularFile ?? false else {
            return 0
        }
        
        return UInt64(resourceValues.totalFileAllocatedSize ?? resourceValues.fileAllocatedSize ?? 0)
    }
    
    var contents: [URL] {
        let _contents = try? FileManager.default.contentsOfDirectory(at: self, includingPropertiesForKeys: [])
        return _contents ?? []
    }
    
    var isDirectory: Bool {
        let resolvedURL = URL(fileURLWithPath: self.realPath ?? self.path)
        return (try? resolvedURL.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false
    }
    
    var creationDate: Date? {
        try? resourceValues(forKeys: [.creationDateKey]).creationDate
    }
    
    var lastModifiedDate: Date? {
        try? resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate
    }
    
    var lastAccessedDate: Date? {
        try? resourceValues(forKeys: [.contentAccessDateKey]).contentAccessDate
    }
    
    /// The date to which the item was added to it's parent directory
    var addedToDirectoryDate: Date? {
        try? resourceValues(forKeys: [.addedToDirectoryDateKey]).addedToDirectoryDate
    }
    
    var size: Int? {
        if self.isDirectory {
            return nil // TODO: - Good dir support, async for UI
        }
        
        return try? resourceValues(forKeys: [.fileSizeKey]).fileSize
    }
    
    var contentType: UTType? {
        return try? resourceValues(forKeys: [.contentTypeKey]).contentType
    }
    
    /// Display name of the URL path
    var displayName: String {
        return FileManager.default.displayName(atPath: self.path)
    }
    
    /// The path, resolved if a symbolic link
    var realPath: String? {
        return try? FileManager.default.destinationOfSymbolicLink(atPath: self.path)
    }
    
    static var root: URL {
        return URL(fileURLWithPath: "/")
    }
    
    static var home: URL {
        return URL(fileURLWithPath: NSHomeDirectory())
    }
    
    var isSymlink: Bool {
        return (try? FileManager.default.destinationOfSymbolicLink(atPath: self.path)) != nil
    }
    
    var isReadable: Bool {
        return FileManager.default.isReadableFile(atPath: self.path)
    }
    
    /// The image to represent this URL in the UI.
    var displayImage: UIImage? {
        if isDirectory {
            return UIImage(systemName: "folder.fill")
        } else {
            // `UTType.data` is a generic type,
            // return the generic symbol for files for it.
            guard let type = self.contentType, type != .data else {
                return UIImage(systemName: "doc")
            }
            
            if type.isOfType(.text) {
                return UIImage(systemName: "doc.text")
            } else if type.isOfType(.image) {
                return UIImage(systemName: "photo")
            } else if type.isOfType(.audio) {
                return UIImage(systemName: "waveform")
            } else if type.isOfType(.movie) || type.isOfType(.video) {
                return UIImage(systemName: "play")
            } else if type.isOfType(.executable) {
                return UIImage(systemName: "terminal")
            }
            
            return UIImage(systemName: "doc")
        }
    }
    
    func setPermissions(forOwner owner: Permission, group: Permission = [], others: Permission = []) throws {
        let octal = Permission.octalRepresentation(of: [owner, group, others])
        try FileManager.default.setAttributes([.posixPermissions: octal], ofItemAtPath: path)
    }
    
    /// Returns an array of complete URLs to the URL's path components
    func fullPathComponents() -> [URL] {
        var arr: [URL] = []
        let components = self.pathComponents
        for indx in components.indices {
            let item = components[components.startIndex...indx]
                .joined(separator: "/")
                .replacingOccurrences(of: "//", with: "/")
            if item.isEmpty {
                continue
            }
            arr.append(URL(fileURLWithPath: item))
        }
        return arr
    }
    
    var isApplicationsContainerURL: Bool {
        #if targetEnvironment(simulator)
        // on the simulator, the home URL is the app's container,
        // so deleting the app id from the URL gives us the URL for app containers
        return self == URL.home.deletingLastPathComponent()
        #else
        return self == URL(fileURLWithPath: "/private/var/containers/Bundle/Application")
        #endif
    }
    
    var applicationItem: LSApplicationProxy? {
        if self.pathExtension == "app" {
            return ApplicationsManager.shared.application(forBundleURL: self)
        } else if self.deletingLastPathComponent().isApplicationsContainerURL {
            return ApplicationsManager.shared.application(forContainerURL: self)
        }
        
        return nil
    }
}

extension UIViewController {
    func errorAlert(_ errorDescription: String?, title: String, presentingFromIfAvailable presentingVC: UIViewController? = nil) {
        var message: String? = nil
        if let errorDescription = errorDescription {
            message = "Error occured: \(errorDescription)"
        }
        
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(.init(title: "OK", style: .cancel))
        let vcToPresentFrom = presentingVC ?? self
        vcToPresentFrom.present(alert, animated: true)
    }
    
    func errorAlert(_ error: Error, title: String, presentingFromIfAvailable presentingVC: UIViewController? = nil) {
        self.errorAlert(error.localizedDescription, title: title, presentingFromIfAvailable: presentingVC)
    }
    
    func configureNavigationBarToNormal() {
        let navigationBarAppearance = UINavigationBarAppearance()
        navigationBarAppearance.configureWithDefaultBackground()
        navigationController?.navigationBar.compactAppearance = navigationBarAppearance
        navigationController?.navigationBar.scrollEdgeAppearance = navigationBarAppearance
    }
    
    /// Presents the Activity View Controller, with code to make sure it doesn't crash on iPad
    func presentActivityVC(forItems items: [Any]) {
        let vc = UIActivityViewController(activityItems: items, applicationActivities: nil)
        vc.popoverPresentationController?.sourceView = view
        let bounds = view.bounds
        
        vc.popoverPresentationController?.sourceRect = CGRect(x: bounds.midX, y: bounds.midY, width: 0, height: 0)
        self.present(vc, animated: true)
    }
}

extension UIMenu {
    func appending(_ element: UIMenuElement) -> UIMenu {
        var children = self.children
        children.append(element)
        return self.replacingChildren(children)
    }
}

extension UIAlertAction {
    static func cancel(handler: (() -> Void)? = nil) -> UIAlertAction {
        UIAlertAction(title: "Cancel", style: .cancel) { _ in
            handler?()
        }
    }
}
extension FileManager {
    
    /// Calculate the allocated size of a directory and all its contents on the volume.
    ///
    /// As there's no simple way to get this information from the file system the method
    /// has to crawl the entire hierarchy, accumulating the overall sum on the way.
    /// The resulting value is roughly equivalent with the amount of bytes
    /// that would become available on the volume if the directory would be deleted.
    ///
    /// - note: There are a couple of oddities that are not taken into account (like symbolic links, meta data of
    /// directories, hard links, ...).
    func allocatedSizeOfDirectory(at directoryURL: URL) throws -> UInt64 {
        
        // The error handler simply stores the error and stops traversal
        var enumeratorError: Error? = nil
        func errorHandler(_: URL, error: Error) -> Bool {
            enumeratorError = error
            return false
        }
        
        // We have to enumerate all directory contents, including subdirectories.
        let enumerator = self.enumerator(at: directoryURL,
                                         includingPropertiesForKeys: Array(allocatedSizeResourceKeys),
                                         options: [],
                                         errorHandler: errorHandler)!
        
        // We'll sum up content size here:
        var accumulatedSize: UInt64 = 0
        
        // Perform the traversal.
        for item in enumerator {
            
            // Bail out on errors from the errorHandler.
            if enumeratorError != nil { break }
            
            // Add up individual file sizes.
            let contentItemURL = item as! URL
            accumulatedSize += try contentItemURL.regularFileAllocatedSize()
        }
        
        // Rethrow errors from errorHandler.
        if let error = enumeratorError { throw error }
        
        return accumulatedSize
    }
}


fileprivate let allocatedSizeResourceKeys: Set<URLResourceKey> = [
    .isRegularFileKey,
    .fileAllocatedSizeKey,
    .totalFileAllocatedSizeKey,
]

extension NSNotification.Name {
    static var pathGroupsDidChange: NSNotification.Name {
        return NSNotification.Name("pathGroupsDidChange")
    }
}

extension Date {
    func listFormatted() -> String {
        if #available(iOS 15.0, *) {
            return self.formatted(date: .long, time: .shortened)
        } else {
            let dateFormatter = DateFormatter()
            dateFormatter.dateStyle = .long
            dateFormatter.timeStyle = .short
            return dateFormatter.string(from: self)
        }
    }
}

extension Collection {
    subscript(safe safeIndex: Index) -> Element? {
        return self.indices.contains(safeIndex) ? self[safeIndex] : nil
    }
}

extension UTType {
    
    public static func generictypes() -> [UTType] {
        return [
            .content,
            .image,
            .video,
            .text,
            .audio,
            .movie,
            .sourceCode,
            .executable
        ]
    }
    
    public static func audioTypes() -> [UTType] {
        return [
            .audio,
            .mp3,
            .aiff,
            .wav,
            .midi
        ]
    }
    
    public static func programmingTypes() -> [UTType] {
        var arr: [UTType] = [
            .swiftSource,
            .sourceCode,
            .assemblyLanguageSource,
            
            .cSource,
            .objectiveCSource,
            .objectiveCPlusPlusSource,
            .cPlusPlusSource,
            
            .cHeader,
            .cPlusPlusHeader,
            
            .script,
            .shellScript,
            .javaScript,
            .pythonScript,
            .rubyScript,
            .perlScript,
            .phpScript
        ]
        
        // UTType.makefile is 15+
        if #available(iOS 15.0, *) {
            arr.append(.makefile)
        }
        
        return arr
    }
    
    public static func compressedFormatTypes() -> [UTType] {
        return [
            .archive,
            .zip,
            .gzip,
            .bz2
        ]
    }
    
    public static func imageTypes() -> [UTType] {
        return [
            .image,
            .png,
            .gif,
            .jpeg,
            .webP,
            .tiff,
            .bmp,
            .svg,
            .heif
        ]
    }
    
    public static func documentTypes() -> [UTType] {
        return [
            .json,
            .yaml,
            .rtf,
            .xml,
            .propertyList,
            .pdf
        ]
    }
    
    public static func systemTypes() -> [UTType] {
        return [
            .bundle,
            .application,
            .framework,
            .log,
            .database,
            .diskImage,
            .package
        ]
    }
    
    public static func executableTypes() -> [UTType] {
        return [
            .executable,
            UTType(filenameExtension: "dylib")
        ]
            .compactMap { $0 }
    }
    
    public static func allTypes() -> [[UTType]] {
        return [
            generictypes(),
            audioTypes(),
            programmingTypes(),
            compressedFormatTypes(),
            imageTypes(),
            documentTypes(),
            executableTypes(),
            systemTypes(),
        ]
    }
    
    /// Checks whether the type is equal to the type given in the parameters
    /// or a parameter of said type
    func isOfType(_ type: UTType) -> Bool {
        return type == self || self.isSubtype(of: type)
    }
}

extension UITableViewController {
    func indexPaths(forSection section: Int) -> [IndexPath] {
        let allRows = self.tableView(tableView, numberOfRowsInSection: section)
        return (0..<allRows).map { row in
            return IndexPath(row: row, section: section)
        }
    }
    
    func cellWithView(_ view: UIView, text: String, rightAnchorConstant: CGFloat = -20) -> UITableViewCell {
        let cell = UITableViewCell()
        var conf = cell.defaultContentConfiguration()
        conf.text = text
        cell.contentConfiguration = conf
        view.translatesAutoresizingMaskIntoConstraints = false
        cell.contentView.addSubview(view)
        
        NSLayoutConstraint.activate([
            view.rightAnchor.constraint(equalTo: cell.contentView.rightAnchor, constant: rightAnchorConstant),
            view.centerYAnchor.constraint(equalTo: cell.contentView.centerYAnchor)
        ])
        
        return cell
    }
    
    /// A title view for a header, containing a button and a title
    func sectionHeaderWithButton(
        sectionTag: Int,
        titleText: String?,
        buttonCustomization: (UIButton) -> Void
    ) -> UIView {
        let view = UIView()
        let label = UILabel()
        let button = UIButton()
        buttonCustomization(button)
        
        button.tag = sectionTag
        
        label.text = titleText
        label.font = UIFont.systemFont(ofSize: 18, weight: .bold)
        
        label.translatesAutoresizingMaskIntoConstraints = false
        button.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(label)
        view.addSubview(button)
        
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 10),
            label.topAnchor.constraint(equalTo: view.topAnchor, constant: 10),
            
            button.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -5),
            button.topAnchor.constraint(equalTo: view.topAnchor, constant: 5),
        ])
        
        return view
    }
    
    /// Returns a UIView of a footer view of the tableView's seperator color
    func seperatorFooterView() -> UIView {
        let result = UIView()
        // recreate insets from existing ones in the table view
        let insets = tableView.separatorInset
        let width = tableView.bounds.width - insets.left - insets.right
        let sepFrame = CGRect(x: insets.left, y: -0.5, width: width, height: 0.5)
        
        // create layer with separator, setting color
        let sep = CALayer()
        sep.frame = sepFrame
        sep.backgroundColor = tableView.separatorColor?.cgColor
        result.layer.addSublayer(sep)
        
        return result
    }
    
    func deleteURL(_ url: URL, completionHandler: @escaping (Bool) -> Void) {
        let confirmationController = UIAlertController(title: "Are you sure you want to delete \"\(url.lastPathComponent)\"?", message: nil, preferredStyle: .alert)
        let deleteAction = UIAlertAction(title: "Delete", style: .destructive) { _ in
            do {
                try FileManager.default.removeItem(at: url)
                completionHandler(true)
            } catch {
                self.errorAlert(error, title: "Failed to delete \"\(url.lastPathComponent)\"")
                completionHandler(false)
            }
        }
        
        let cancelAction: UIAlertAction = .cancel {
            completionHandler(false)
        }
        
        confirmationController.addAction(deleteAction)
        confirmationController.addAction(cancelAction)
        self.present(confirmationController, animated: true)
    }
}

extension UIImage {
    func imageWith(newSize: CGSize) -> UIImage {
        let image = UIGraphicsImageRenderer(size: newSize).image { _ in
            draw(in: CGRect(origin: .zero, size: newSize))
        }
        
        return image.withRenderingMode(renderingMode)
    }
}

extension UIAction {
    convenience init(withClosure closure: @escaping () -> Void) {
        self.init { _ in
            closure()
        }
    }
}
 
// why the hell is this not built in already?
extension Optional: Comparable where Wrapped: Comparable {
    public static func < (lhs: Optional, rhs: Optional) -> Bool {
        guard let lhs = lhs, let rhs = rhs else {
            return false
        }
        
        return lhs < rhs
    }
}


extension UITableView.Style: CaseIterable, CustomStringConvertible {
    static var userPreferred: UITableView.Style {
        return UITableView.Style(rawValue: UserPreferences.preferredTableViewStyle) ?? .insetGrouped
    }
    
    public static var allCases: [UITableView.Style] = [.insetGrouped, .grouped, .plain]
    
    public var description: String {
        switch self {
        case .plain:
            return "Plain"
        case .grouped:
            return "Grouped"
        case .insetGrouped:
            return "Inset Grouped"
        @unknown default:
            return "Unknown Mode"
        }
    }
}

extension Array where Element: OptionSet {
    // bizzare! see https://forums.swift.org/t/reducing-array-optionset-to-optionset/4438/8
    func reducingToSingleOptionSet() -> Element {
        return self.reduce(Element()) { return $0.union($1) }
    }
}

extension passwd {
    init?(fileURLOwner fileURL: URL) {
        var buffer = stat()
        guard lstat(fileURL.path, &buffer) == 0, let pwd = getpwuid(buffer.st_uid)?.pointee else {
            return nil
        }
        
        self = pwd
    }
}

extension UIUserInterfaceStyle: CaseIterable {
    public static var allCases: [UIUserInterfaceStyle] = [.unspecified, .dark, .light]
    var description: String {
        switch self {
        case .unspecified:
            return "System"
        case .light:
            return "Light"
        case .dark:
            return "Dark"
        @unknown default:
            return "Unknown Mode"
        }
    }
}

extension UITableViewCell {
    func colorCircleAccessoryView(color: UIColor) -> UIView {
        let colorPreview = UIView(frame: CGRect(x: 0, y: 0, width: 29, height: 29))
        colorPreview.backgroundColor = color
        colorPreview.layer.cornerRadius = colorPreview.frame.size.width / 2
        colorPreview.layer.borderWidth = 1.5
        colorPreview.layer.borderColor = UIColor.systemGray.cgColor
        
        return colorPreview
    }
}

extension Dictionary<String, SerializedItemType> {
    func asAnyDictionary() -> [String: Any] {
        var dict: [String: Any] = [:]
        for (key, value) in self {
            dict[key] = value.representedObject
        }
        
        return dict
    }
}

extension Dictionary<String, Any> {
    func asSerializedDictionary() -> SerializedDictionaryType {
        var dict: SerializedDictionaryType = [:]
        for (key, value) in self {
            dict[key] = SerializedItemType(item: value)
        }
        
        return dict
    }
}

extension UIDevice {
    var isiPad: Bool {
        return userInterfaceIdiom == .pad
    }
}

extension DateFormatter {
    /// A Date Formatter which could be used to format dates
    /// used in EXIF metadata
    static var EXIFDateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy:MM:dd HH:mm:ss"
        return formatter
    }
    
    static var IPTCDateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd"
        return formatter
    }
}

extension UIApplication {
    var sceneKeyWindow: UIWindow? {
        return UIApplication.shared
        .connectedScenes
        .flatMap { ($0 as? UIWindowScene)?.windows ?? [] }
        .first { $0.isKeyWindow }
    }
}

extension CTFontDescriptor {
    var uiFont: UIFont {
        return CTFontCreateWithFontDescriptor(self, UserPreferences.fontViewerFontSize, nil) as UIFont
    }
}
