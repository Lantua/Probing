//
//  File.swift
//  
//
//  Created by Natchanon Luangsomboon on 4/3/2563 BE.
//

import Foundation
import ArgumentParser

@propertyWrapper
struct Undecoded<Value>: Decodable {
    var storage: Value!

    init() { }
    init(from decoder: Decoder) { }

    var wrappedValue: Value {
        get { storage }
        set { storage = newValue }
    }
}
