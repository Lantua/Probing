import Socket
import Probing
import Foundation
import LNTCSVCoder

guard let commandURL = CommandLine.arguments.dropFirst().first.map(URL.init(fileURLWithPath:)),
    let outputURL = CommandLine.arguments.dropFirst(2).first.map(URL.init(fileURLWithPath:)),
    let id = CommandLine.arguments.dropFirst(3).first.map(Int.init(_:)) as? Int else {
    print("must supply file path as first argument")
    exit(-1)
}
let baseName = commandURL.deletingPathExtension().lastPathComponent
let name = baseName.withCString {
    String(format: "%s-%03d", $0, id)
}

extension FileHandle: TextOutputStream {
    public func write(_ string: String) {
        write(Data(string.utf8))
    }
}

let encoder: CSVEncoder
if FileManager.default.fileExists(atPath: outputURL.path) {
    encoder = CSVEncoder(options: .omitHeader)
} else {
    FileManager.default.createFile(atPath: outputURL.path, contents: nil) 
    encoder = CSVEncoder()
}

var stats: [Int: Stats] = [:]
var output = try FileHandle(forWritingTo: outputURL), queue = DispatchQueue(label: "File Queue")
output.seekToEndOfFile()

let command: Command
let currentTime = Date() + 0.5
do {
    let list = try JSONDecoder().decode([Command].self, from: NSData(contentsOf: commandURL) as Data)
    guard list.indices ~= id else {
        print("id (\(id)) out of range (\(list.indices))")
        exit(-7)
    }
    command = list[id]
} catch {
    print("Invalid JSON file ", commandURL.absoluteString, ": ", error)
    exit(-1)
}

let runningGroup = DispatchGroup()
var threads: [Thread] = []

do {
    for (port, pattern) in command["127.0.0.1"] ?? [:] {
        let packetSize = pattern.packetSize
        let backlogSize = pattern.maxSize
        let logger = StatsDataTraceOutputStream(startTime: currentTime) { rate, cv in
            queue.sync {
                stats[port, default: .init(name: name, port: port)].set(output: rate, cv: cv)
            }
        }

        do {
            let thread = try UDPClient.listen(on: port, packetSize: packetSize, maxBacklogSize: backlogSize, group: runningGroup, logger: logger)
            threads.append(thread)
        } catch {
            print("Could not open listening Client at port ", port, ": ", error)
            continue
        }
    }
}

let sender = try UDPClient()
for (host, command) in command {
    for (port, pattern) in command {
        let packetSize = pattern.packetSize
        let backlogSize = pattern.maxSize
        let address = Socket.createAddress(for: host, on: Int32(port))!

        let duration = (currentTime + pattern.startTime)..<(currentTime + (pattern.endTime ?? .infinity))
 
        let logger = StatsDataTraceOutputStream(startTime: currentTime) { rate, cv in
            queue.sync {
                stats[port, default: .init(name: name, port: port)].set(input: rate, cv: cv)
            }
        }
        let thread = try sender.send(pattern: pattern.getSequence(), to: address, duration: duration, packetSize: packetSize, maxBacklogSize: backlogSize, group: runningGroup, logger: logger)
        threads.append(thread)
    }
}

signal(SIGTERM, SIG_IGN)
let sigSrc = DispatchSource.makeSignalSource(signal: SIGTERM, queue: .main)
sigSrc.setEventHandler {
    threads.forEach { $0.cancel() }
    runningGroup.wait()

    let values = stats.sorted(by: { $0.key < $1.key }).map { $0.value }
    try? encoder.encode(values, into: &output)

    exit(0)
}
sigSrc.resume()

dispatchMain()
