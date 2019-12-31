//
//  Client.swift
//  Probing
//
//  Created by Natchanon Luangsomboon on 10/2/2562 BE.
//

import Socket
import Foundation
import Dispatch

let headerSize = 42

public class UDPClient {
    let socket: Socket

    public init() throws {
        socket = try Socket.create(family: .inet, type: .datagram, proto: .udp)
    }

    public func send<S>(pattern: S, to destination: Socket.Address, duration: Range<Date>, packetSize: Int, backlogSize: Int, group: DispatchGroup, logger: DataTraceOutputStream?) where S: Sequence, S.Element == CommandPattern.Element {
        let startTime = duration.lowerBound, endTime = duration.upperBound
        let payloadSize = max(packetSize - headerSize, MemoryLayout<Tag>.size)
        let packetSize = payloadSize + headerSize

        let maxBlockCount = (backlogSize + packetSize - 1) / packetSize
        let buffer = UnsafeMutablePointer<Tag>.allocate(capacity: maxBlockCount + payloadSize / MemoryLayout<Tag>.stride)

        DispatchQueue.global().async(group: group) { [socket] in
            defer { buffer.deallocate() }

            var tag: Tag = 0

            for (offset, size) in pattern {
                let currentTime = startTime + offset
                guard currentTime < endTime else {
                    break
                }

                let fullBlockCount = size / packetSize, residual = size % packetSize
                for i in 0...fullBlockCount {
                    buffer[i] = (tag + i).littleEndian
                }

                Thread.sleep(until: currentTime)

                do {
                    for i in 0..<fullBlockCount {
                        try socket.write(from: buffer + i, bufSize: payloadSize, to: destination)
                    }

                    if residual != 0 {
                        do {
                            try socket.write(from: buffer + fullBlockCount, bufSize: max(residual - headerSize, MemoryLayout<Tag>.size))
                        }
                    }
                } catch {
                    print("Error sending data: ", error)
                    break
                }

                let sentTime = Date()
                if let logger = logger {
                    for i in 0..<fullBlockCount {
                        logger.write(.init(id: tag &+ i, time: sentTime, size: packetSize))
                    }
                    if residual != 0 {
                        logger.write(.init(id: tag &+ fullBlockCount, time: sentTime, size: max(residual, MemoryLayout<Tag>.size + headerSize)))
                    }
                }

                tag &+= fullBlockCount
                if residual != 0 {
                    tag += 1
                }
            }
            logger?.write(.init(id: -1, time: Date(), size: 0))
            logger?.finalize()
        }
    }

    deinit {
        socket.close()
    }
}

