//
//  LoadingValueState.swift
//  Santander
//
//  Created by Serena on 08/11/2022
//


import Foundation

/// Describes the state of a value which can be loaded in the UI asynchronously,
/// ie, loading the size of a path
enum LoadingValueState<Value> {
    case loading
    case unavailable
    case value(Value)
}
