import Socket
import Foundation
import ArgumentParser

struct Forward: ParsableCommand {
    @Argument() var host: String
    @Argument() var destinationPort: Int
    @Argument() var listeningPorts: [Int]

    func run() throws {
        let runningGroup = DispatchGroup()

        for port in listeningPorts {
            let address = Socket.createAddress(for: host, on: Int32(port))!

            DispatchQueue.global().async(group: runningGroup) {
                do {
                    try forward(to: address, on: port, until: .distantFuture, packetSize: 5000, backlogSize: 5000)
                } catch {
                    print("Forwarding Error: \(error)")
                }
            }
        }

        runningGroup.wait()
    }
}

@available(OSX 10.12, *)
private func forward(to destination: Socket.Address, on port: Int, until: Date, packetSize: Int, backlogSize: Int) throws {
    let socket = try Socket.create(family: .inet, type: .datagram, proto: .udp)
    try socket.setReadTimeout(value: 1000)
    try socket.listen(on: port, maxBacklogSize: backlogSize)

    let buffer = UnsafeMutableRawPointer.allocate(byteCount: packetSize, alignment: 1)
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
            // Time out
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
