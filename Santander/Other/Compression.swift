//
//  Compression.swift
//  Santander
//
//  Created by Serena on 14/08/2022.
//

import Foundation
import Minizip

class Compression {
    static let shared = Compression()
    
    public func zipFiles(
        paths: [URL],
        zipFilePath: URL,
        password: String? = nil,
        compression: ZipCompression = .defaultCompression,
        progress: ((_ progress: Double) -> ())? = nil
    ) throws {
        // File manager
        let fileManager = FileManager.default
        
        // Check whether a zip file exists at path.
        let destinationPath = zipFilePath.path
        
        // Process zip paths
        let processedPaths = processZipPaths(paths)
        
        // Zip set up
        let chunkSize: Int = 16384
        
        // Progress handler set up
        var currentPosition: Double = 0.0
        var totalSize: Double = 0.0
        // Get totalSize for progress handler
        for path in processedPaths {
            if let fileAttrs = try? fileManager.attributesOfItem(atPath: path.filePathURL.path), let fileSize = fileAttrs[.size] as? Double {
                totalSize += fileSize
            }
        }
        
        let progressTracker = Progress(totalUnitCount: Int64(totalSize))
        progressTracker.isCancellable = false
        progressTracker.isPausable = false
        progressTracker.kind = ProgressKind.file
        
        // Begin Zipping
        let zip = zipOpen(destinationPath, APPEND_STATUS_CREATE)
        for path in processedPaths {
            if !path.filePathURL.isDirectory {
                let filePath = path.filePathURL.path
                
                guard let input = fopen(filePath, "r") else {
                    throw ZipErrors.unableToOpenFile
                }
                
                defer { fclose(input) }
                
                let fileName = path.fileName
                var zipInfo: zip_fileinfo = zip_fileinfo(tmz_date: tm_zip(tm_sec: 0, tm_min: 0, tm_hour: 0, tm_mday: 0, tm_mon: 0, tm_year: 0), dosDate: 0, internal_fa: 0, external_fa: 0)
                if let fileAttrs = try? fileManager.attributesOfItem(atPath: filePath) {
                    if let fileDate = fileAttrs[.modificationDate] as? Date {
                        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute, .second], from: fileDate)
                        zipInfo.tmz_date.tm_sec = UInt32(components.second!)
                        zipInfo.tmz_date.tm_min = UInt32(components.minute!)
                        zipInfo.tmz_date.tm_hour = UInt32(components.hour!)
                        zipInfo.tmz_date.tm_mday = UInt32(components.day!)
                        zipInfo.tmz_date.tm_mon = UInt32(components.month!) - 1
                        zipInfo.tmz_date.tm_year = UInt32(components.year!)
                    }
                    
                    if let fileSize = fileAttrs[.size] as? Double {
                        currentPosition += fileSize
                    }
                }
                
                guard let buffer = malloc(chunkSize) else {
                    throw ZipErrors.unableToAllocateMemory
                }
                
                defer {
                    free(buffer)
                }
                
                if let password = password {
                    zipOpenNewFileInZip3(zip, fileName, &zipInfo, nil, 0, nil, 0, nil, Z_DEFLATED, compression._minizipValue, 0, -MAX_WBITS, DEF_MEM_LEVEL, Z_DEFAULT_STRATEGY, password, 0)
                }
                
                else {
                    zipOpenNewFileInZip3(zip, fileName, &zipInfo, nil, 0, nil, 0, nil, Z_DEFLATED, compression._minizipValue, 0, -MAX_WBITS, DEF_MEM_LEVEL, Z_DEFAULT_STRATEGY, nil, 0)
                }
                
                var length: Int = 0
                while (feof(input) == 0) {
                    length = fread(buffer, 1, chunkSize, input)
                    zipWriteInFileInZip(zip, buffer, UInt32(length))
                }
                
                // Update progress handler, only if progress is not 1, because
                // if we call it when progress == 1, the user will receive
                // a progress handler call with value 1.0 twice.
                if let progressHandler = progress, currentPosition / totalSize != 1 {
                    progressHandler(currentPosition/totalSize)
                }
                
                progressTracker.completedUnitCount = Int64(currentPosition)
                
                zipCloseFileInZip(zip)
            }
        }
        zipClose(zip, nil)
        
        // Completed. Update progress handler.
        if let progressHandler = progress{
            progressHandler(1.0)
        }
        
        progressTracker.completedUnitCount = Int64(totalSize)
    }
    
    public func unzipFile(
        _ zipFilePath: URL,
        destination: URL,
        overwrite: Bool,
        password: String? = nil,
        progress: ((_ progress: Double) -> ())? = nil,
        fileOutputHandler: ((_ unzippedFile: URL) -> Void)? = nil
    ) throws {
        
        // File manager
        let fileManager = FileManager.default
        
        // Check whether a zip file exists at path.
        let path = zipFilePath.path
        
        // Unzip set up
        var ret: Int32 = 0
        var crc_ret: Int32 = 0
        let bufferSize: UInt32 = 4096
        var buffer = Array<CUnsignedChar>(repeating: 0, count: Int(bufferSize))
        
        // Progress handler set up
        var totalSize: Double = 0.0
        var currentPosition: Double = 0.0
        let fileAttributes = try fileManager.attributesOfItem(atPath: path)
        if let attributeFileSize = fileAttributes[FileAttributeKey.size] as? Double {
            totalSize += attributeFileSize
        }
        
        let progressTracker = Progress(totalUnitCount: Int64(totalSize))
        progressTracker.isCancellable = false
        progressTracker.isPausable = false
        progressTracker.kind = ProgressKind.file
        
        // Begin unzipping
        let zip = unzOpen64(path)
        defer {
            unzClose(zip)
        }
        if unzGoToFirstFile(zip) != UNZ_OK {
            throw ZipErrors.unableToOpenFile
        }
        
        repeat {
            if let cPassword = password?.cString(using: String.Encoding.ascii) {
                ret = unzOpenCurrentFilePassword(zip, cPassword)
            }
            else {
                ret = unzOpenCurrentFile(zip);
            }
            if ret != UNZ_OK {
                throw ZipErrors.unableToOpenFile
            }
            var fileInfo = unz_file_info64()
            memset(&fileInfo, 0, MemoryLayout<unz_file_info>.size)
            ret = unzGetCurrentFileInfo64(zip, &fileInfo, nil, 0, nil, 0, nil, 0)
            if ret != UNZ_OK {
                unzCloseCurrentFile(zip)
                throw ZipErrors.unableToGetFileInfo
            }
            
            currentPosition += Double(fileInfo.compressed_size)
            let fileNameSize = Int(fileInfo.size_filename) + 1
            //let fileName = UnsafeMutablePointer<CChar>(allocatingCapacity: fileNameSize)
            let fileName = UnsafeMutablePointer<CChar>.allocate(capacity: fileNameSize)

            unzGetCurrentFileInfo64(zip, &fileInfo, fileName, UInt(fileNameSize), nil, 0, nil, 0)
            fileName[Int(fileInfo.size_filename)] = 0

            var pathString = String(cString: fileName)
            
            var isDirectory = false
            let fileInfoSizeFileName = Int(fileInfo.size_filename-1)
            if (fileName[fileInfoSizeFileName] == "/".cString(using: String.Encoding.utf8)?.first || fileName[fileInfoSizeFileName] == "\\".cString(using: String.Encoding.utf8)?.first) {
                isDirectory = true;
            }
            free(fileName)
            if pathString.rangeOfCharacter(from: CharacterSet(charactersIn: "/\\")) != nil {
                pathString = pathString.replacingOccurrences(of: "\\", with: "/")
            }

            let fullPath = destination.appendingPathComponent(pathString).path

            let creationDate = Date()

            let directoryAttributes: [FileAttributeKey: Any] = [.creationDate : creationDate, .modificationDate : creationDate]

            do {
                if isDirectory {
                    try fileManager.createDirectory(atPath: fullPath, withIntermediateDirectories: true, attributes: directoryAttributes)
                }
                else {
                    let parentDirectory = (fullPath as NSString).deletingLastPathComponent
                    try fileManager.createDirectory(atPath: parentDirectory, withIntermediateDirectories: true, attributes: directoryAttributes)
                }
            } catch {}
            if fileManager.fileExists(atPath: fullPath) && !isDirectory && !overwrite {
                unzCloseCurrentFile(zip)
                ret = unzGoToNextFile(zip)
            }

            var writeBytes: UInt64 = 0
            var filePointer: UnsafeMutablePointer<FILE>?
            filePointer = fopen(fullPath, "wb")
            while filePointer != nil {
                let readBytes = unzReadCurrentFile(zip, &buffer, bufferSize)
                if readBytes > 0 {
                    guard fwrite(buffer, Int(readBytes), 1, filePointer) == 1 else {
                        throw ZipErrors.unknownError
                    }
                    writeBytes += UInt64(readBytes)
                }
                else {
                    break
                }
            }

            if let fp = filePointer { fclose(fp) }

            crc_ret = unzCloseCurrentFile(zip)
            if crc_ret == UNZ_CRCERROR {
                throw ZipErrors.unknownError
            }
            
            guard writeBytes == fileInfo.uncompressed_size else {
                throw ZipErrors.unzipSizeMismatch
            }

            //Set file permissions from current fileInfo
            if fileInfo.external_fa != 0 {
                let permissions = (fileInfo.external_fa >> 16) & 0x1FF
                //We will devifne a valid permission range between Owner read only to full access
                if permissions >= 0o400 && permissions <= 0o777 {
                    do {
                        try fileManager.setAttributes([.posixPermissions : permissions], ofItemAtPath: fullPath)
                    } catch {
                        print("Failed to set permissions to file \(fullPath), error: \(error)")
                    }
                }
            }

            ret = unzGoToNextFile(zip)
            
            // Update progress handler
            if let progressHandler = progress{
                progressHandler((currentPosition/totalSize))
            }
            
            if let fileHandler = fileOutputHandler,
                let encodedString = fullPath.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
                let fileUrl = URL(string: encodedString) {
                fileHandler(fileUrl)
            }
            
            progressTracker.completedUnitCount = Int64(currentPosition)
            
        } while (ret == UNZ_OK && ret != UNZ_END_OF_LIST_OF_FILE)
        
        // Completed. Update progress handler.
        if let progressHandler = progress{
            progressHandler(1.0)
        }
        
        progressTracker.completedUnitCount = Int64(totalSize)
        
    }
    
    enum ZipErrors: Error, LocalizedError {
        case unableToOpenFile
        case unableToAllocateMemory
        case unableToGetFileInfo
        case unknownError
        case unzipSizeMismatch
        
        var errorDescription: String? {
            switch self {
            case .unableToOpenFile:
                return "Unable to open file."
            case .unableToAllocateMemory:
                return "Unable to allocate memory."
            case .unableToGetFileInfo:
                return "Unable to get file information."
            case .unzipSizeMismatch:
                return "Size mismatch when unzipping."
            case .unknownError:
                return "Unknown Error."
            }
        }
    }
    
    enum ZipCompression {
        case noCompression
        case bestSpeed
        case defaultCompression
        case bestCompression
        
        fileprivate var _minizipValue: Int32 {
            switch self {
            case .noCompression:
                return Z_NO_COMPRESSION
            case .bestSpeed:
                return Z_BEST_SPEED
            case .bestCompression:
                return Z_BEST_COMPRESSION
            case .defaultCompression:
                return Z_DEFAULT_COMPRESSION
            }
        }
    }
    
    internal struct ProcessedFilePath {
        let filePathURL: URL
        
        var fileName: String {
            filePathURL.lastPathComponent
        }
    }
    
    //MARK: Path processing
    
    /**
     Process zip paths
     
     - parameter paths: Paths as NSURL.
     
     - returns: Array of ProcessedFilePath structs.
     */
    internal func processZipPaths(_ paths: [URL]) -> [ProcessedFilePath] {
        var processedFilePaths = [ProcessedFilePath]()
        for path in paths {
            if !path.isDirectory {
                let processedPath = ProcessedFilePath(filePathURL: path)
                processedFilePaths.append(processedPath)
            }
            else {
                let directoryContents = expandDirectoryFilePath(path)
                processedFilePaths.append(contentsOf: directoryContents)
            }
        }
        return processedFilePaths
    }
    
    
    /**
     Expand directory contents and parse them into ProcessedFilePath structs.
     
     - parameter directory: Path of folder as NSURL.
     
     - returns: Array of ProcessedFilePath structs.
     */
    internal func expandDirectoryFilePath(_ directory: URL) -> [ProcessedFilePath] {
        var processedFilePaths = [ProcessedFilePath]()
        let directoryPath = directory.path
        if let enumerator = FileManager.default.enumerator(atPath: directoryPath) {
            while let filePathComponent = enumerator.nextObject() as? String {
                let path = directory.appendingPathComponent(filePathComponent)
                
                if !path.isDirectory {
                    let processedPath = ProcessedFilePath(filePathURL: path)
                    processedFilePaths.append(processedPath)
                }
            }
        }
        return processedFilePaths
    }
    
}
