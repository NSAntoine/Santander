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
        case (.data(let first), .data(let second)):             return first == second
        case (.date(let first), .date(let second)):             return first == second
        case (.array(let first), .array(let second)):
            return NSArray(array: first) == NSArray(array: second)
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
    case array(Array<Any>)
    case dictionary([String: Any])
    case data(Data)
    case date(Date)
    case other(Any)
    
    init(item: Any) {
        switch item {
        case let string as String:
            self = .string(string)
        case let nsNumber as NSNumber:
            // handle bools
            if CFGetTypeID(nsNumber) == CFBooleanGetTypeID() {
                self = .bool(nsNumber.boolValue)
            } else {
                // handle numbers
                switch CFNumberGetType(nsNumber as CFNumber) {
                case .floatType, .float32Type, .float64Type, .cgFloatType, .doubleType:
                    self = .float(nsNumber.floatValue)
                default:
                    self = .int(nsNumber.intValue)
                }
            }
        case let arr as Array<Any>:
            self = .array(arr)
        case let dictionary as Dictionary<String, Any>:
            self = .dictionary(dictionary)
        case let data as NSData:
            self = .data(data as Data)
        case let date as NSDate:
            self = .date(date as Date)
        default:
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
        case .array(let array):
            return array.description
        case .dictionary(let nsDictionary):
            return nsDictionary.description
        case .date(let date):
            return date.listFormatted()
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
        case .date(_):
            return "Date"
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
        case .data(let data):
            return data
        case .date(let date):
            return date
        case .other(let any):
            return any
        }
    }
    
}

enum SerializedControllerParent {
    case dictionary(SerializedDocumentViewController)
    case array(SerializedArrayViewController)
}
