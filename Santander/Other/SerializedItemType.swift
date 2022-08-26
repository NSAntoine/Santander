//
//  SerializedItemType.swift
//  Santander
//
//  Created by Serena on 17/08/2022.
//

import Foundation

enum SerializedItemType: Equatable, CustomStringConvertible {
    static func == (lhs: SerializedItemType, rhs: SerializedItemType) -> Bool {
        switch (lhs, rhs) {
        case (.string(let first), .string(let second)):         return first == second
        case (.bool(let first), .bool(let second)):             return first == second
        case (.int(let first), .int(let second)):               return first == second
        case (.float(let first), .float(let second)):           return first == second
        case (.array(let first), .array(let second)):           return first == second
        case (.dictionary(let first), .dictionary(let second)):
            return NSDictionary(dictionary: first) == NSDictionary(dictionary: second)
        default:
            return false
        }
    }
    
    case string(String)
    case bool(Bool)
    case int(Int)
    case float(Float)
    case array(NSArray)
    case dictionary([String: Any])
    case data(NSData)
    case other(Any)
    
    init(item: Any) {
        if let item = item as? String {
            self = .string(item)
        } else if let item = item as? NSNumber {
            // handle bools
            if CFGetTypeID(item) == CFBooleanGetTypeID() {
                self = .bool(item.boolValue)
            } else {
                // handle numbers
                switch CFNumberGetType(item as CFNumber) {
                case .floatType, .float32Type, .float64Type, .cgFloatType, .doubleType:
                    self = .float(item.floatValue)
                default:
                    self = .int(item.intValue)
                }
            }
        } else if let item = item as? NSArray {
            self = .array(item)
        } else if let item = item as? Dictionary<String, Any> {
            self = .dictionary(item)
        } else if let item = item as? NSData {
            self = .data(item)
        } else {
            self = .other(item)
        }
    }
    
    var description: String {
        switch self {
        case .string(let string):
            return string
        case .bool(let bool):
            return bool.description
        case .int(let int):
            return int.description
        case .float(let float):
            return float.description
        case .array(let nsArray):
            return (nsArray as? Array<Any>)?.description ?? nsArray.description
        case .dictionary(let nsDictionary):
            return nsDictionary.description
        case .data(let data):
            return "Data (Size: \(data.count))"
        case .other(let any):
            return String(describing: any)
        }
    }
    
    var typeDescription: String {
        switch self {
        case .string(_):
            return "String"
        case .bool(_):
            return "Boolean"
        case .int(_):
            return "Integer"
        case .float(_):
            return "Float"
        case .data(_):
            return "Data"
        case .array(_):
            return "Array"
        case .dictionary(_):
            return "Dictionary"
        case .other(_):
            return "Unknown Type"
        }
    }
    
    var representedObject: Any {
        switch self {
        case .string(let string):
            return string
        case .bool(let bool):
            return bool
        case .int(let int):
            return int
        case .float(let float):
            return float
        case .array(let nsArray):
            return nsArray
        case .dictionary(let nsDictionary):
            return nsDictionary
        case .data(let nsData):
            return nsData
        case .other(let any):
            return any
        }
    }
    
}
