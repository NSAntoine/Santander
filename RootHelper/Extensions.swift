//
//  Extensions.swift
//  RootHelper
//
//  Created by Serena on 10/11/2022
//
	

import Foundation
import ArgumentParser
import CompressionWrapper

extension URL: ExpressibleByArgument {
    public init?(argument: String) {
        self.init(fileURLWithPath: argument)
    }
}

// not an extension, but useful
struct StringError: LocalizedError, CustomStringConvertible {
    let description: String
    
    init(_ description: String) {
        self.description = description
    }
    
    var errorDescription: String? {
        description
    }
}

extension Compression.FormatType: ExpressibleByArgument {
    public init?(argument: String) {
        switch argument {
        case "zip":
            self = .zip
        case "tar":
            self = .tar
        default:
            return nil
        }
    }
}
