//
//  File.swift
//  
//
//  Created by Natchanon Luangsomboon on 6/3/2563 BE.
//

import Foundation

public struct TraceRow: Codable {
    public var time: TimeInterval, rate: Double

    public init(time: TimeInterval, rate: Double) {
        self.time = time
        self.rate = rate
    }
}
