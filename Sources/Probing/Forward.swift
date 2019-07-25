import Foundation
import Socket

extension UDPClient {
    @available(OSX 10.12, *)
    public func forward(to destination: Socket.Address, on port: Int, packetSize: Int, maxBacklog: Int) throws {
        try socket.listen(on: port, maxBacklogSize: maxBacklog)
        try socket.setReadTimeout(value: 1000)

        let thread = Thread { [socket = self.socket, group = self.runningGroup] in
            group.enter()
            defer { group.leave() }

            let buffer = UnsafeMutableRawPointer.allocate(byteCount: packetSize, alignment: 1)
            defer {
                buffer.deallocate()
            }
            while true {
                guard let size = try? socket.readDatagram(into: buffer.assumingMemoryBound(to: CChar.self), bufSize: packetSize).bytesRead else {
                    if Thread.current.isCancelled {
                        break
                    } else {
                        continue
                    }
                }

                guard size != 0 else {
                    // Disconnected
                    break
                }

                do {
                    try socket.write(from: buffer, bufSize: size, to: destination)
                } catch {
                    print("Error sending data: ", error)
                    continue
                }
            }
        }
        thread.start()

        threads.append(thread)
    }
}
