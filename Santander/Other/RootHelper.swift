//
//  FSOperation.swift
//  Santander
//
//  Created by Serena on 15/09/2022
//


import Foundation
@_exported import FSOperations // export FSOperations to rest of Santander module
import NSTaskBridge

struct RootConf: RootHelperConfiguration {
    private init() {}
    
    static let shared = RootConf()
    
    private func __setupNSTask(executableURL: URL, arguments: [String]) -> NSTask {
        let task = NSTask()
        task.executableURL = executableURL
        task.arguments = arguments
        return task
    }
    
    private func rootHelperURL() throws -> URL {
        guard let rootHelperURL = Bundle.main.url(forAuxiliaryExecutable: "RootHelper"),
              FileManager.default.fileExists(atPath: rootHelperURL.path) else {
            throw Errors.rootHelperUnavailable
        }
        
        return rootHelperURL
    }
    
    func perform(_ operation: FSOperation) throws {
        let rootHelperURL = try rootHelperURL()
        let task = __setupNSTask(executableURL: rootHelperURL, arguments: [operation.commandLineInvokation])
        
        try task.launchAndReturnError()
        task.waitUntilExit()
        guard task.terminationStatus == 0 else {
            throw Errors.rootHelperReturnedFailure(task: task)
        }
    }
    
    /// Return the contents of a directory which can't be read as 'mobile'
    func contents(of path: URL) throws -> [URL] {
        let rootHelper = try rootHelperURL()
        let task = __setupNSTask(executableURL: rootHelper, arguments: ["get-contents \(path.path)"])
        try task.launchAndReturnError()
        task.waitUntilExit()
        
        guard let data = try task.standardOutput.fileHandleForReading.readToEnd(), let string = String(data: data, encoding: .utf8) else {
            throw Errors.unableToReadHelperOutput
        }
        
        return string.components(separatedBy: " ").map { URL(fileURLWithPath: $0) }
    }
    
    
    var useRootHelper: Bool {
        return UserPreferences.rootHelperIsEnabled
    }
    
    private enum Errors: Error, LocalizedError, CustomStringConvertible {
        case rootHelperUnavailable
        case rootHelperReturnedFailure(task: NSTask)
        case unableToReadHelperOutput
        
        var description: String {
            switch self {
            case .rootHelperUnavailable:
                return "Root Helper unavailable? is your install messed up?"
            case .rootHelperReturnedFailure(let task):
                var output: String? = nil
                if let data = try? task.standardOutput.fileHandleForReading.readToEnd() {
                    output = String(data: data, encoding: .utf8)
                }
                
                return "Root Helper failed with exit code \(task.terminationStatus)\nOutput: \(output ?? "Unknown")"
            case .unableToReadHelperOutput:
                return "Unable to read root helper output"
            }
        }
        
        var errorDescription: String? {
            description
        }
    }
}
