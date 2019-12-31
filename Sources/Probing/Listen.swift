import Foundation
import Socket 

extension UDPClient {
    public static func listen(on port: Int, until: Date, packetSize: Int, backlogSize: Int, group: DispatchGroup, logger: DataTraceOutputStream) throws {
        let socket = try Socket.create(family: .inet, type: .datagram, proto: .udp)
        try socket.setReadTimeout(value: 100)
        try socket.listen(on: port, maxBacklogSize: backlogSize)

        DispatchQueue.global().async(group: group) {
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

                guard until.timeIntervalSinceNow >= 0 else {
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
    }
}
