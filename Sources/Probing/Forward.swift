import Foundation
import Socket

extension UDPClient {
    @available(OSX 10.12, *)
    public static func forward(to destination: Socket.Address, on port: Int, until: Date, packetSize: Int, backlogSize: Int, group: DispatchGroup) throws {
        let socket = try Socket.create(family: .inet, type: .datagram, proto: .udp)
        try socket.setReadTimeout(value: 1000)
        try socket.listen(on: port, maxBacklogSize: backlogSize)

        let buffer = UnsafeMutableRawPointer.allocate(byteCount: packetSize, alignment: 1)

        DispatchQueue.global().async(group: group) {
            defer { buffer.deallocate() }

            while true {
                let size: Int
                do {
                    size = try socket.readDatagram(into: buffer.assumingMemoryBound(to: CChar.self), bufSize: packetSize).bytesRead
                } catch {
                    print("Error receiving data: ", error)
                    continue
                }

                guard until.timeIntervalSinceNow >= 0 else {
                    break
                }
                guard size > 0 else {
                    continue
                }

                do {
                    try socket.write(from: buffer, bufSize: size, to: destination)
                } catch {
                    print("Error sending data: ", error)
                    continue
                }
            }
        }
    }
}
