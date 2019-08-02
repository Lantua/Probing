import Socket
import Probing
import Foundation
import CSVCoder

guard let commandPath = CommandLine.arguments.dropFirst().first,
    let outputPath = CommandLine.arguments.dropFirst(2).first,
    let id = CommandLine.arguments.dropFirst(3).first.map(Int.init(_:)) as? Int else {
    print("must supply file path as first argument")
    exit(-1)
}
let commandURL = URL(fileURLWithPath: commandPath, isDirectory: false)
let outputURL = URL(fileURLWithPath: outputPath, isDirectory: false)

let baseName = commandURL.deletingPathExtension().lastPathComponent
let name = baseName.withCString {
    String(format: "%s-%03d", $0, id)
}

let existed = FileManager.default.fileExists(atPath: outputPath)
if !existed {
    FileManager.default.createFile(atPath: outputPath, contents: nil) 
}

var output = try FileHandle(forWritingTo: outputURL)
output.seekToEndOfFile()

let commands: [Command]
let currentTime = Date() + 0.5
do {
    let list = try JSONDecoder().decode([[Command]].self, from: NSData(contentsOf: commandURL) as Data)
    guard list.indices ~= id else {
        print("id (\(id)) out of range (\(list.indices))")
        exit(-7)
    }
    commands = list[id]
} catch {
    print("Invalid JSON file ", commandURL.absoluteString, ": ", error)
    exit(-1)
}

let sender = try UDPClient()
var listeners: [UDPClient] = []

var senderLoggers: [Int: StatsDataTraceOutputStream] = [:]
var listenerLoggers: [Int: StatsDataTraceOutputStream] = [:]

do {
    let ports = commands.map { $0.port }
    let packetSizes = Dictionary(zip(ports, commands.map { $0.packetSize }), uniquingKeysWith: max)
    let backlogSizes = Dictionary(zip(ports, commands.map { $0.pattern.maxSize }), uniquingKeysWith: +)

    for port in Set(ports) {
        listenerLoggers[port] = StatsDataTraceOutputStream(startTime: currentTime)
        senderLoggers[port] = StatsDataTraceOutputStream(startTime: currentTime)

        do {
            try listeners.append(UDPClient(port: port, packetSize: packetSizes[port]!, backlogSize: backlogSizes[port]!, logger: listenerLoggers[port]!))
        } catch {
            print("Could not open listening Client at port ", port, ": ", error)
            continue
        }
    }
}

for command in commands {
    let packetSize = command.packetSize
    let destination = Socket.createAddress(for: command.destination, on: Int32(command.port))!

    let pattern = command.pattern
    let backlogSize = pattern.maxSize
    let startTime = currentTime + pattern.startTime
    let duration = pattern.duration ?? .infinity
 
    try sender.send(pattern: pattern.getSequence(), to: destination, startTime: startTime, duration: duration, packetSize: packetSize, maxBacklogSize: backlogSize, logger: senderLoggers[command.port]!)
}

extension FileHandle: TextOutputStream {
    public func write(_ string: String) {
        write(Data(string.utf8))
    }
}

signal(SIGTERM, SIG_IGN)
let sigSrc = DispatchSource.makeSignalSource(signal: SIGTERM, queue: .main)
sigSrc.setEventHandler {
    sender.close()
    for listener in listeners {
        listener.close()
    }

    sender.finalize()
    for listener in listeners {
        listener.finalize()
    }

    var stats: [Int: Stats] = [:]
    for (port, logger) in listenerLoggers {
        let (output, cv) = logger.computeStats()
        stats[port, default: .init(name: name, port: port)].set(output: output, outputCV: cv)
    }
    for (port, logger) in senderLoggers {
        let (input, cv) = logger.computeStats()
        stats[port, default: .init(name: name, port: port)].set(input: input, inputCV: cv)
    }

    var encoder = CSVEncoder()
    if existed {
        encoder.options.insert(.skipHeader)
    }
    let values = stats.sorted(by: { $0.key < $1.key }).map { $0.value }
    try? encoder.encode(values, into: &output)

    exit(0)
}
sigSrc.resume()

dispatchMain()
