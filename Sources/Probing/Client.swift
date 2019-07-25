//
//  Client.swift
//  Probing
//
//  Created by Natchanon Luangsomboon on 10/2/2562 BE.
//

import Socket
import Foundation
import Dispatch

public class UDPClient {
    let socket: Socket, runningGroup = DispatchGroup()

    var threads: [Thread] = []

    public init() throws {
        socket = try Socket.create(family: .inet, type: .datagram, proto: .udp)
    }

    @available(OSX 10.12, *)
    public func send<S>(pattern: S, to destination: Socket.Address, startTime: Date, duration: Double, packetSize: Int, maxBacklogSize: Int, logger: (DataTraceOutputStream & AnyObject)?) where S: Sequence, S.Element == CommandPattern.Element {
        let thread = Thread { [socket = self.socket, group = self.runningGroup] in
            group.enter()
            defer { group.leave() }

            assert(packetSize % MemoryLayout<Tag>.alignment == 0)
            let buffer = UnsafeMutableRawPointer.allocate(byteCount: maxBacklogSize, alignment: MemoryLayout<Tag>.alignment)
            defer {
                buffer.deallocate()
            }

            var tag: Tag = 0

            for (time, size) in pattern {
                guard !Thread.current.isCancelled,
                    duration > time else {
                        break
                }

                for (tagOffset, startIndex) in stride(from: 0, to: size, by: packetSize).enumerated() {
                    buffer.storeBytes(of: (tag + Tag(tagOffset)).bigEndian, toByteOffset: startIndex, as: Tag.self)
                }

                Thread.sleep(until: startTime + time)
                for startIndex in stride(from: 0, to: size, by: packetSize) {
                    let chunkSize = max(0, min(packetSize, size - startIndex) - 42)
                    do {
                        try socket.write(from: buffer.advanced(by: startIndex), bufSize: chunkSize, to: destination)
                    } catch {
                        print("Error sending data: ", error)
                        continue
                    }
                }

                let sentTime = Date()
                for startIndex in stride(from: 0, to: size, by: packetSize) {
                    let chunkSize = min(packetSize, size - startIndex)
                    logger?.write(.init(id: tag, time: sentTime, size: chunkSize))
                    tag += 1
                }
            }
        }
        thread.start()

        threads.append(thread)
    }

    @available(OSX 10.12, *)
    func listen(on port: Int, packetSize: Int, maxBacklogSize: Int, logger: (DataTraceOutputStream & AnyObject)) throws {
        var logger = logger

        try socket.setReadTimeout(value: 1000)
        try socket.listen(on: port, maxBacklogSize: maxBacklogSize)

        let thread = Thread { [socket = self.socket, group = self.runningGroup] in
            group.enter()
            defer { group.leave() }

            let buffer = UnsafeMutableRawPointer.allocate(byteCount: packetSize, alignment: MemoryLayout<Tag>.alignment)
            defer {
                buffer.deallocate()
            }

            while true {
                let size: Int
                do {
                    size = try socket.readDatagram(into: buffer.assumingMemoryBound(to: CChar.self), bufSize: packetSize).bytesRead + 42
                } catch {
                    guard !Thread.current.isCancelled else {
                        break
                    }
                    print("Error receiving data: ", error)
                    continue
                }

                guard size != 42 else {
                    // Timeout
                    continue
                }

                let currentTime = Date(), tag = buffer.load(as: Tag.self).bigEndian
                logger.write(.init(id: tag, time: currentTime, size: size))
            }
        }
        thread.start()

        threads.append(thread)
    }

    public func close() {
        for thread in threads {
            thread.cancel()
        }

        socket.close()
    }
    public func finalize() {
        runningGroup.wait()
    }

    deinit {
        close()
    }
}

public extension UDPClient {
    @available(OSX 10.12, *)
    convenience init(port: Int, packetSize: Int, backlogSize: Int, logger: (DataTraceOutputStream & AnyObject)) throws {
        try self.init()
        
        try listen(on: port, packetSize: packetSize, maxBacklogSize: backlogSize, logger: logger)
    }
}

