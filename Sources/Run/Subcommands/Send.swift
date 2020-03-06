//
//  Client.swift
//  Probing
//
//  Created by Natchanon Luangsomboon on 10/2/2562 BE.
//

import Socket
import Foundation
import Dispatch
import ArgumentParser

let headerSize = 42

struct Send: ParsableCommand {
    @OptionGroup() var outputArguments: OutputArguments
    @OptionGroup() var commandArguments: CommandArguments

    func run() throws {
        let socket = try Socket.create(family: .inet, type: .datagram, proto: .udp)
        let startTime = Date(), runningGroup = DispatchGroup()
        let duration = commandArguments.duration, packetSize = commandArguments.packetSize

        for (host, command) in commandArguments.command {
            for (port, patterns) in command where !patterns.isEmpty {
                let address = Socket.createAddress(for: host, on: Int32(port))!
                let sequences = patterns.map { $0.getSequence() }
                let commands = CommandPattern.merge(commands: sequences, until: duration)
                let logger = StatsDataTraceOutputStream(startTime: startTime) { sizes, interval in
                    DispatchQueue.global(qos: .background).async(group: runningGroup) {
                        self.outputArguments.register(port: port, interval: interval, sizes: sizes, isInput: true)
                    }
                }

                DispatchQueue.global().async(group: runningGroup) {
                    do {
                        try send(socket: socket, pattern: commands, to: address, startTime: startTime, packetSize: packetSize, logger: logger)
                    } catch {
                        print("Sending Error: \(error)")
                    }
                }
            }
        }

        runningGroup.wait()
    }
}

private func send<S>(socket: Socket, pattern: S, to destination: Socket.Address, startTime: Date, packetSize: Int, logger: DataTraceOutputStream?) throws where S: Sequence, S.Element == CommandPattern.Element {
    let payloadSize = max(packetSize - headerSize, 0)
    let packetSize = payloadSize + headerSize

    let buffer = UnsafeMutableRawPointer.allocate(byteCount: payloadSize, alignment: 1)
    defer { buffer.deallocate() }

    for (offset, size) in pattern {
        let currentTime = startTime + offset
        let fullBlockCount = size / packetSize, residual = size % packetSize

        Thread.sleep(until: currentTime)

        for _ in 0..<fullBlockCount {
            try socket.write(from: buffer, bufSize: payloadSize, to: destination)
        }

        if residual != 0 {
            try socket.write(from: buffer + fullBlockCount, bufSize: max(residual - headerSize, 0))
        }

        logger?.write(.init(time: Date(), size: size))
    }
    logger?.write(.init(time: Date(), size: 0))
    logger?.finalize()
}

