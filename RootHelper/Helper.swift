//
//  SantanderRootHelper.swift
//  SantanderRootHelper
//
//  Created by Serena on 17/10/2022
//

import Foundation
import FSOperations

// stub
struct RootHelperAction: Codable {
    let operation: FSOperation
}

// I don't feel like making an error enum so
struct StringError: Error, LocalizedError, CustomStringConvertible {
    let description: String
    
    init(_ description: String) {
        self.description = description
    }
    
    var errorDescription: String? {
        self.description
    }
}


@main
struct RootHelper {
    static func main() async throws {
        NSLog("Root Helper Awaken.")
        NSLog("Bitch im back from my coma")
        try getRoot()
        
        let operationURL = Bundle.main.bundleURL.appendingPathComponent("CurrentRootOperation.json")
        let decoded = try JSONDecoder().decode(RootHelperAction.self, from: Data(contentsOf: operationURL))
        try FSOperation.perform(decoded.operation, rootHelperConf: nil)
    }
    
    static func getRoot() throws {
        setuid(0)
        setgid(0)
        
        guard getuid() == 0 else {
            throw StringError("ROOT HELPER ERROR: Unable to get root.")
        }
    }
}
