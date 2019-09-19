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
var threads: [Thread] = []

for port in listenPorts {
    let address = Socket.createAddress(for: host, on: Int32(port))!

    do {
        let thread = try UDPClient.forward(to: address, on: port, packetSize: 5000, maxBacklogSize: 5000, group: runningGroup)
        threads.append(thread)
    } catch {
        print("Could not create forwarder at port ", port, ": ", error)
        continue
    }
}

runningGroup.wait()
