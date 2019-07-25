//
//  JSON.swift
//  Run
//
//  Created by Natchanon Luangsomboon on 11/2/2562 BE.
//

import Foundation
import Probing

struct SendPattern: Codable {
    var type: String
    var rate: Double?
    var maxSize: Int
    var url: URL?
    var startTime: TimeInterval, duration: Double?

    func getSequence() throws -> AnySequence<CommandPattern.Element> {
        switch type {
        case "cbr": return AnySequence(CommandPattern.cbr(rate: rate! / 8, size: maxSize))
        case "poisson": return AnySequence(CommandPattern.poisson(rate: rate! / 8, size: maxSize))
        case "file": return try AnySequence(CommandPattern.custom(url: url!))
        default: fatalError("Unknown send pattern \(type)")
        }
    }
}

struct Command: Codable {
    var destination: String
    var port: Int32

    var pattern: SendPattern
    var packetSize: Int
}

