import Foundation
import Socket 

extension UDPClient {
    @available(OSX 10.12, *)
    public static func listen(on port: Int, packetSize: Int, maxBacklogSize: Int, group: DispatchGroup, logger: DataTraceOutputStream) throws -> Thread {
        var logger = logger

        let socket = try Socket.create(family: .inet, type: .datagram, proto: .udp)
        try socket.setReadTimeout(value: 100)
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
}
