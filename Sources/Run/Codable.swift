//
//  Codable.swift
//  Run
//
//  Created by Natchanon Luangsomboon on 11/2/2562 BE.
//

import Foundation
import Probing

struct SendPattern: Codable {
    enum PatternType: String, Codable {
        case cbr, poisson, file
    }
    var type: PatternType
    var rate: Double?
    var maxSize: Int
    var url: URL?
    var startTime: TimeInterval, duration: Double?

    func getSequence() throws -> AnySequence<CommandPattern.Element> {
        switch type {
        case .cbr: return AnySequence(CommandPattern.cbr(rate: rate! / 8, size: maxSize))
        case .poisson: return AnySequence(CommandPattern.poisson(rate: rate! / 8, size: maxSize))
        case .file: return try AnySequence(CommandPattern.custom(url: url!))
        }
    }
}

struct Command: Codable {
    var destination: String
    var port: Int

    var pattern: SendPattern
    var packetSize: Int
}

struct Stats: Codable {
    var name: String, port: Int, inputCV, outputCV, input, output: Double?

    init(name: String, port: Int) {
        self.name = name
        self.port = port
    }

    mutating func set(input: Double, inputCV: Double) {
        assert(self.input == nil)
        self.input = input
        self.inputCV = inputCV
    }

    mutating func set(output: Double, outputCV: Double) {
        assert(self.output == nil)
        self.output = output
        self.outputCV = outputCV
    }
}
