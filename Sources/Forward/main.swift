import Socket
import Probing
import Foundation

guard (2...).contains(CommandLine.arguments.count - 1),
    let destinationPort = Int(CommandLine.arguments[2]) else {
    print("forward <Destination Host> <port>...")
    exit(-1)
}

let host = CommandLine.arguments[1]
let listenPorts: [Int] = CommandLine.arguments.dropFirst(2).map {
    guard let tmp = Int($0) else {
        print("forward <Destination Host> <port>...")
        exit(-1)
    }
    return tmp
}

let runningGroup = DispatchGroup()

for port in listenPorts {
    let address = Socket.createAddress(for: host, on: Int32(port))!

    do {
        try UDPClient.forward(to: address, on: port, until: .distantFuture, packetSize: 5000, backlogSize: 5000, group: runningGroup)
    } catch {
        print("Could not create forwarder at port ", port, ": ", error)
        continue
    }
}

runningGroup.wait()
