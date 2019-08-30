//
//  Codable.swift
//  Run
//
//  Created by Natchanon Luangsomboon on 11/2/2562 BE.
//

import Foundation
import Probing

typealias Command = [String: [Int: SendPattern]]

struct SendPattern: Codable {
    enum PatternType: String, Codable {
        case cbr, poisson, file
    }
    var type: PatternType
    var rate: Double?, url: URL?
    var packetSize, maxSize: Int
    var startTime: TimeInterval, endTime: TimeInterval?

    var listeningPort: Int?

    func getSequence() throws -> AnySequence<CommandPattern.Element> {
        switch type {
        case .cbr: return AnySequence(CommandPattern.cbr(rate: rate! / 8, size: maxSize))
        case .poisson: return AnySequence(CommandPattern.poisson(rate: rate! / 8, size: maxSize))
        case .file: return try AnySequence(CommandPattern.custom(url: url!))
        }
    }
}

struct Stats: Codable {
    var name: String, port: Int, inputCV, outputCV, input, output: Double?

    init(name: String, port: Int) {
        self.name = name
        self.port = port
    }

    mutating func set(input: Double, cv: Double) {
        assert(self.input == nil)
        self.input = input
        self.inputCV = cv
    }

    mutating func set(output: Double, cv: Double) {
        assert(self.output == nil)
        self.output = output
        self.outputCV = cv
    }
}
