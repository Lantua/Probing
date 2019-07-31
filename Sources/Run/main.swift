import Socket
import Probing
import Foundation

guard let argument1 = CommandLine.arguments.dropFirst().first,
    let argument2 = CommandLine.arguments.dropFirst(2).first else {
    print("must supply file path as first argument")
    exit(-1)
}
let jsonFile = URL(fileURLWithPath: argument1, isDirectory: false)
let id = Int(argument2)!
let directory = jsonFile.deletingPathExtension().appendingPathExtension("data").appendingPathComponent("\(id)")
try? FileManager.default.removeItem(at: directory)
try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

let commands: [Command]
let currentTime = Date() + 0.5
do {
    let list = try JSONDecoder().decode([[Command]].self, from: NSData(contentsOf: jsonFile) as Data)
    guard list.indices ~= id else {
        print("id (\(id)) out of range (\(list.indices))")
        exit(-7)
    }
    commands = list[id]
} catch {
    print("Invalid JSON file ", jsonFile.absoluteString, ": ", error)
    exit(-1)
}
var listeningClients: [UDPClient] = []

for listener in commands {
    let port = Int(listener.port)
    let packetSize = listener.packetSize
    let backlogSize = listener.pattern.maxSize

    let logFile = directory.appendingPathComponent("\(listener.port).out")
    let logger: DataTraceOutputStream
    do {
        try "".write(to: logFile, atomically: true, encoding: .utf8)
        logger = try FileDataTraceOutputStream(url: logFile, startTime: currentTime)
    } catch {
        print("Could not open ", logFile.absoluteString, " for writing: ", error)
        continue
    }
    do {
        let client = try UDPClient(port: port, packetSize: packetSize, backlogSize: backlogSize, logger: logger)
        listeningClients.append(client)
    } catch {
        print("Could not open listening Client at port ", port, ": ", error)
        continue
    }
}

let client = try UDPClient()

for command in commands {
    let packetSize = command.packetSize
    let destination = Socket.createAddress(for: command.destination, on: command.port)!

    let logFile = directory.appendingPathComponent("\(command.port).in")
    var logger: DataTraceOutputStream?
    do {
        try "".write(to: logFile, atomically: true, encoding: .utf8)
        logger = try FileDataTraceOutputStream(url: logFile, startTime: currentTime)
    } catch {
        print("Could not open ", logFile.absoluteString, " for writing: ", error)
    }

    let pattern = command.pattern
    do {
        let backlogSize = pattern.maxSize
        let startTime = currentTime + pattern.startTime
        let duration = pattern.duration ?? .infinity
 
        try client.send(pattern: pattern.getSequence(), to: destination, startTime: startTime, duration: duration, packetSize: packetSize, maxBacklogSize: backlogSize, logger: logger)
    }
}

signal(SIGTERM, SIG_IGN)
let sigSrc = DispatchSource.makeSignalSource(signal: SIGTERM, queue: .main)
sigSrc.setEventHandler {
    client.close()
    for client in listeningClients {
        client.close()
    }

    client.finalize()
    for client in listeningClients {
        client.finalize()
    }

    listeningClients = []
    exit(0)
}
sigSrc.resume()

dispatchMain()
