//
//  SendReceive.swift
//  
//
//  Created by Natchanon Luangsomboon on 3/3/2563 BE.
//

import Foundation
import Socket
import Probing
import ArgumentParser

struct Send: ParsableCommand {
    @OptionGroup() var nested: RunnerArgument

    func run() throws {
        let runner = try Runner(argument: nested)
        try runner.send()
        try runner.finalize()
    }
}

struct Receive: ParsableCommand {
    @OptionGroup() var nested: RunnerArgument

    func run() throws {
        let runner = try Runner(argument: nested)
        try runner.receive()
        try runner.finalize()
    }
}

struct SendReceive: ParsableCommand {
    @OptionGroup() var nested: RunnerArgument

    func run() throws {
        let runner = try Runner(argument: nested)
        try runner.receive()
        try runner.send()
        try runner.finalize()
    }
}

enum RunnerError: Error {
    case UnsupportedPacketSize
}

final class Runner {
    let startTime = Date() + 0.5
    let runningGroup = DispatchGroup()
    let command: Command

    var plot: Plot?, summary: Summary?
    let duration: Double

    init(argument: RunnerArgument) throws {
        command = try Command(argument: argument.experimentSpec)
        summary = Summary(argument.summary, commandURL: argument.experimentSpec.commandURL)
        plot = try Plot(argument: argument.plot, commandURL: argument.experimentSpec.commandURL, experimentationID: argument.experimentSpec.experimentationID)
        duration = argument.duration
    }

    func run() throws {
        try receive()
        try send()
        try finalize()
    }

    func send() throws {
        let sender = try UDPClient()

        for (host, command) in command {
            for (port, patterns) in command where !patterns.isEmpty {
                let address = Socket.createAddress(for: host, on: Int32(port))!
                let logger = StatsDataTraceOutputStream(startTime: startTime) { sizes, interval in
                    DispatchQueue.global(qos: .background).async(group: self.runningGroup) {
                        let (rate, cv) = computeRateCV(sizes: sizes, interval: interval)
                        self.plot?.plot(port: port, suffix: "in", interval: interval, sizes: sizes)
                        self.summary?.register(port: port, stats: Stats(name: "", port: port, inputCV: cv, input: rate))
                    }
                }
                let packetSize = patterns.first!.maxPacketSize

                guard patterns.dropFirst().allSatisfy({ packetSize == $0.maxPacketSize }) else {
                    throw RunnerError.UnsupportedPacketSize
                }

                let backlogSize = patterns.lazy.map { $0.maxBurstSize }.reduce(0, +)
                let sequences = patterns.map { $0.getSequence() }

                sender.send(pattern: CommandPattern.merge(commands: sequences, until: duration), to: address, startTime: startTime, packetSize: packetSize, backlogSize: backlogSize, group: runningGroup, logger: logger)
            }
        }
    }

    func receive() throws {
        guard plot != nil || summary != nil else {
            return
        }

        for spec in command.values {
            for (port, patterns) in spec where !patterns.isEmpty {
                let packetSize = patterns.lazy.map { $0.maxPacketSize }.max()!
                let backlogSize = patterns.lazy.map { $0.maxBurstSize }.reduce(0, +)
                let logger = StatsDataTraceOutputStream(startTime: startTime) { sizes, interval in
                    DispatchQueue.global(qos: .background).async(group: self.runningGroup) {
                        let (rate, cv) = computeRateCV(sizes: sizes, interval: interval)
                        self.plot?.plot(port: port, suffix: "out", interval: interval, sizes: sizes)
                        self.summary?.register(port: port, stats: Stats(name: "", port: port, outputCV: cv, output: rate))
                    }
                }

                try UDPClient.listen(on: port, until: startTime + duration, packetSize: packetSize, backlogSize: backlogSize, group: runningGroup, logger: logger)
            }
        }
    }

    func finalize() throws {
        runningGroup.wait()
        try summary?.summarize()
    }
}

func computeRateCV(sizes: [Int], interval: Double) -> (rate: Double, cv: Double) {
    let rates = sizes.dropLast().map { Double($0) * 8 / interval }
    guard !rates.isEmpty else {
        return (0, 0)
    }

    let mean = rates.reduce(0, +) / Double(rates.count)
    let variance = rates.map { ($0 - mean) * ($0 - mean) }.reduce(0, +) / Double(rates.count)

    return (mean, sqrt(variance) / mean)
}
