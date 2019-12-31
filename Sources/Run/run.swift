//
//  send.swift
//  
//
//  Created by Natchanon Luangsomboon on 30/12/2562 BE.
//

import Foundation
import LNTCSVCoder
import Probing
import Socket

extension FileHandle: TextOutputStream {
    public func write(_ string: String) {
        write(Data(string.utf8))
    }
}

private func computeRateCV(sizes: [Int], interval: Double) -> (rate: Double, cv: Double) {
    let rates = sizes.dropLast().map { Double($0) * 8 / interval }
    guard !rates.isEmpty else {
        return (0, 0)
    }

    let mean = rates.reduce(0, +) / Double(rates.count)
    let variance = rates.map { ($0 - mean) * ($0 - mean) }.reduce(0, +) / Double(rates.count)

    return (mean, sqrt(variance) / mean)
}

class Runner {
    let startTime = Date() + 0.5, endTime: Date
    let command: Command, plotting: Bool

    let queue = DispatchQueue(label: "Runner"), runningGroup = DispatchGroup()
    var stats: [Int: Stats] = [:]

    init(command: Command, plotting: Bool, duration: Double) {
        self.command = command
        self.plotting = plotting
        endTime = startTime + duration
    }

    func send() throws {
        let sender = try UDPClient()

        for (host, command) in command {
            for (port, pattern) in command {
                let packetSize = pattern.maxPacketSize, backlogSize = pattern.maxBurstSize
                let address = Socket.createAddress(for: host, on: Int32(port))!

                let duration = ((startTime + pattern.startTime)..<(startTime + pattern.endTime)).clamped(to: startTime..<endTime)
                let logger = StatsDataTraceOutputStream(startTime: startTime) { self.processSendingLog(port: port, sizes: $0, interval: $1) }

                try sender.send(pattern: pattern.getSequence(), to: address, duration: duration, packetSize: packetSize, backlogSize: backlogSize, group: runningGroup, logger: logger)
            }
        }
    }

    func receive() throws {
        for spec in command.values {
            for (port, pattern) in spec {
                let packetSize = pattern.maxPacketSize, backlogSize = pattern.maxBurstSize
                let logger = StatsDataTraceOutputStream(startTime: startTime) { self.processReceivingLog(port: port, sizes: $0, interval: $1) }

                try UDPClient.listen(on: port, until: endTime, packetSize: packetSize, backlogSize: backlogSize, group: runningGroup, logger: logger)
            }
        }
    }

    private func processSendingLog(port: Int, sizes: [Int], interval: TimeInterval) {
        if plotting {
            fatalError("Unsupported function: Plotting")
        } else {
            let (rate, cv) = computeRateCV(sizes: sizes, interval: interval)
            queue.sync {
                //print("SEND \(port)"); sizes.enumerated().forEach { print("\($0.offset), \($0.element)") }
                stats[port, default: .init(name: name, port: port)].set(input: rate, cv: cv)
            }
        }
    }

    private func processReceivingLog(port: Int, sizes: [Int], interval: TimeInterval) {
        if plotting {
            fatalError("Unsupported function: Plotting")
        } else {
            let (rate, cv) = computeRateCV(sizes: sizes, interval: interval)
            queue.sync {
                //print("RECV \(port)"); sizes.enumerated().forEach { print("\($0.offset), \($0.element)") }
                stats[port, default: .init(name: name, port: port)].set(output: rate, cv: cv)
            }
        }
    }
}
