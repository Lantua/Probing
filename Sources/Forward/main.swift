import Socket
import Probing
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

            do {
                try UDPClient.forward(to: address, on: port, until: .distantFuture, packetSize: 5000, backlogSize: 5000, group: runningGroup)
            } catch {
                print("Could not create forwarder at port ", port, ": ", error)
                continue
            }
        }

        runningGroup.wait()
    }
}

Forward.main()
