//
//  Storage.swift
//  Santander
//
//  Created by Serena on 06/07/2022
//
	

import Foundation

@propertyWrapper
struct Storage<T> {
    let key: String
    let defaultValue: T

    init(key: String, defaultValue: T) {
        self.key = key
        self.defaultValue = defaultValue
    }

    var wrappedValue: T {
        get {
            return UserDefaults.standard.object(forKey: key) as? T ?? defaultValue
        }
        
        set {
            UserDefaults.standard.set(newValue, forKey: key)
        }
    }
}

@propertyWrapper
struct CodableStorage<T: Codable> {
    let key: String
    let defaultValue: T
    var didChange: (() -> Void)?
    
    init(key: String, defaultValue: T, didChange: (() -> Void)?) {
        self.key = key
        self.defaultValue = defaultValue
        self.didChange = didChange
    }
    
    var wrappedValue: T {
        get {
            guard let data = UserDefaults.standard.data(forKey: key),
                  let decoded = try? JSONDecoder().decode(T.self, from: data) else {
                return defaultValue
            }
            
            return decoded
        }
        
        set {
            guard let encoded = try? JSONEncoder().encode(newValue) else {
                return
            }
            
            UserDefaults.standard.set(encoded, forKey: key)
            didChange?()
        }
    }
}
