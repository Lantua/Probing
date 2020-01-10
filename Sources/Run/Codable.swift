//
//  Codable.swift
//  Run
//
//  Created by Natchanon Luangsomboon on 11/2/2562 BE.
//

import Foundation
import Probing

typealias Command = [String: [Int: [SendPattern]]]

struct SendPattern {
    enum PatternType {
        case cbr(rate: Double, packetSize: Int)
        case poisson(rate: Double, packetSize: Int)
    }
    var startTime: TimeInterval, endTime: TimeInterval
    var pattern: PatternType

    var maxPacketSize: Int {
        switch pattern {
        case let .cbr(_, packetSize),
             let .poisson(_, packetSize):
            return packetSize
        }
    }

    var maxBurstSize: Int {
        switch pattern {
        case let .cbr(_, packetSize),
             let .poisson(_, packetSize):
            return packetSize
        }
    }

    func getSequence() throws -> AnySequence<CommandPattern.Element> {
        switch pattern {
        case let .cbr(rate, packetSize): return AnySequence(CommandPattern.cbr(rate: rate / 8, size: packetSize, start: startTime, end: endTime))
        case let .poisson(rate, packetSize): return CommandPattern.poisson(rate: rate / 8, size: packetSize, start: startTime, end: endTime)
        }
    }
}

extension SendPattern: Codable {
    private enum CodingKeys: CodingKey {
        case type, rate, url, packetSize, startTime, endTime
    }
    private enum TypeName: String, Codable {
        case cbr, poisson
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        startTime = try container.decode(Double.self, forKey: .startTime)
        endTime = try container.decodeIfPresent(Double.self, forKey: .endTime) ?? .infinity

        switch try container.decode(TypeName.self, forKey: .type) {
        case .cbr:
            let rate = try container.decode(Double.self, forKey: .rate)
            let packetSize = try container.decode(Int.self, forKey: .packetSize)
            pattern = .cbr(rate: rate, packetSize: packetSize)
        case .poisson:
            let rate = try container.decode(Double.self, forKey: .rate)
            let packetSize = try container.decode(Int.self, forKey: .packetSize)
            pattern = .poisson(rate: rate, packetSize: packetSize)
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(startTime, forKey: .startTime)
        if endTime.isFinite {
            try container.encode(endTime, forKey: .endTime)
        }

        switch pattern {
        case let .cbr(rate, packetSize):
            try container.encode(TypeName.cbr, forKey: .type)
            try container.encode(rate, forKey: .rate)
            try container.encode(packetSize, forKey: .packetSize)
        case let .poisson(rate, packetSize):
            try container.encode(TypeName.poisson, forKey: .type)
            try container.encode(rate, forKey: .rate)
            try container.encode(packetSize, forKey: .packetSize)
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
