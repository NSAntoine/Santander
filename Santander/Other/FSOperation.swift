//
//  FSOperation.swift
//  Santander
//
//  Created by Serena on 15/09/2022
//


import Foundation
@_exported import FSOperations // export FSOperations to rest of Santander module
import NSTaskBridge

fileprivate struct RootHelperAction: Codable {
    let operation: FSOperation
}

struct RootConf: RootHelperConfiguration {
    private init() {}
    
    static let rootHelperURL = Bundle.main.bundleURL.appendingPathComponent("CurrentRootOperation.json")
    static let shared = RootConf()
    
    
    var action: ActionHandler = { operation in
        // encode the operation
        try JSONEncoder().encode(RootHelperAction(operation: operation)).write(to: RootConf.rootHelperURL)
        
        guard let rootHelperURL = Bundle.main.url(forAuxiliaryExecutable: "RootHelper") else {
            throw Errors.rootHelperUnavailable
        }
        
        let task = NSTask()
        task.executableURL = rootHelperURL
        
        try task.launchAndReturnError()
        task.waitUntilExit()
        guard task.terminationStatus == 0 else {
            throw Errors.rootHelperReturnedFailure(task: task)
        }
    }
    
    var useRootHelper: Bool {
        return UserPreferences.rootHelperIsEnabled
    }
    
    private enum Errors: Error, LocalizedError, CustomStringConvertible {
        case rootHelperUnavailable
        case rootHelperReturnedFailure(task: NSTask)
        
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
            }
        }
        
        var errorDescription: String? {
            description
        }
    }
}
