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

    @available(OSX 10.12, *)
    public func send<S>(pattern: S, to destination: Socket.Address, duration: Range<Date>, packetSize: Int, maxBacklogSize: Int, group: DispatchGroup, logger: DataTraceOutputStream?) -> Thread where S: Sequence, S.Element == CommandPattern.Element {
        let startTime = duration.lowerBound, endTime = duration.upperBound
        let payloadSize = max(packetSize - headerSize, MemoryLayout<Tag>.size)
        let packetSize = payloadSize + headerSize

        let maxBlockCount = (maxBacklogSize + packetSize - 1) / packetSize
        let buffer = UnsafeMutablePointer<Tag>.allocate(capacity: maxBlockCount + payloadSize / MemoryLayout<Tag>.stride)

        let thread = Thread { [socket = self.socket] in
            group.enter()
            defer { group.leave() }

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
                guard !Thread.current.isCancelled else {
                    break
                }

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
        thread.start()
        return thread
    }

    @available(OSX 10.12, *)
    public static func listen(on port: Int, packetSize: Int, maxBacklogSize: Int, group: DispatchGroup, logger: DataTraceOutputStream) throws -> Thread {
        var logger = logger

        let socket = try Socket.create(family: .inet, type: .datagram, proto: .udp)
        try socket.setReadTimeout(value: 1000)
        try socket.listen(on: port, maxBacklogSize: maxBacklogSize)

        let thread = Thread {
            group.enter()
            defer { group.leave() }

            let buffer = UnsafeMutableRawPointer.allocate(byteCount: packetSize, alignment: MemoryLayout<Tag>.alignment)
            defer {
                buffer.deallocate()
            }

            while true {
                let size: Int
                do {
                    size = try socket.readDatagram(into: buffer.assumingMemoryBound(to: CChar.self), bufSize: packetSize).bytesRead + headerSize
                } catch {
                    print("Error receiving data: ", error)
                    continue
                }

                guard !Thread.current.isCancelled else {
                    break
                }
                guard size >= MemoryLayout<Tag>.size + headerSize else {
                    // Timeout
                    continue
                }

                let currentTime = Date(), tag = buffer.load(as: Tag.self).littleEndian
                logger.write(.init(id: tag, time: currentTime, size: size))
            }
            logger.write(.init(id: -1, time: Date(), size: 0))
            logger.finalize()
        }
        thread.start()
        return thread
    }

    deinit {
        socket.close()
    }
}

