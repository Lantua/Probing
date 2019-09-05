import Socket
import Probing
import Foundation
import LNTCSVCoder

guard CommandLine.arguments.indices.contains(4),
    let id = Int(CommandLine.arguments[3]),
    let totalDuration = Double(CommandLine.arguments[4]) else {
    print("<Command URL> <Output URL> <ID> <Duration>")
    exit(-1)
}

let commandURL = URL(fileURLWithPath: CommandLine.arguments[1])
let outputURL = URL(fileURLWithPath: CommandLine.arguments[2])

let baseName = commandURL.deletingPathExtension().lastPathComponent
let name = baseName.withCString {
    String(format: "%s-%03d", $0, id)
}

extension FileHandle: TextOutputStream {
    public func write(_ string: String) {
        write(Data(string.utf8))
    }
}

func computeRateCV(sizes: [Int], interval: Double) -> (rate: Double, cv: Double) {
    var rate = 0.0, cv = 0.0

    let rates = sizes.dropLast().map { Double($0) * 8 / interval }
    guard !rates.isEmpty else {
        return (0, 0)
    }

    let mean = rates.reduce(0, +) / Double(rates.count)
    let variance = rates.map { ($0 - mean) * ($0 - mean) }.reduce(0, +) / Double(rates.count)

    rate = mean
    cv = sqrt(variance) / mean
    return (rate, cv)
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
        let listeningPort = pattern.listeningPort ?? port
        let logger = StatsDataTraceOutputStream(startTime: currentTime) { sizes, interval in
            let (rate, cv) = computeRateCV(sizes: sizes, interval: interval)
            queue.sync {
                //print("RECV \(port)"); sizes.enumerated().forEach { print("\($0.offset), \($0.element)") }
                stats[port, default: .init(name: name, port: port)].set(output: rate, cv: cv)
            }
        }

        do {
            let thread = try UDPClient.listen(on: listeningPort, packetSize: packetSize, maxBacklogSize: backlogSize, group: runningGroup, logger: logger)
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
        let logger = StatsDataTraceOutputStream(startTime: currentTime) { sizes, interval in
            let (rate, cv) = computeRateCV(sizes: sizes, interval: interval)
            queue.sync {
                //print("SENT \(port)"); sizes.enumerated().forEach { print("\($0.offset), \($0.element)") }
                stats[port, default: .init(name: name, port: port)].set(input: rate, cv: cv)
            }
        }

        let thread = try sender.send(pattern: pattern.getSequence(), to: address, duration: duration, packetSize: packetSize, maxBacklogSize: backlogSize, group: runningGroup, logger: logger)
        threads.append(thread)
    }
}

let timer = DispatchSource.makeTimerSource()
timer.setEventHandler {
    threads.forEach { $0.cancel() }
    runningGroup.wait()

    let values = stats.sorted(by: { $0.key < $1.key }).map { $0.value }
    try? encoder.encode(values, into: &output)

    exit(0)
}

timer.schedule(wallDeadline: .now() + currentTime.timeIntervalSinceNow + totalDuration)
timer.activate()

dispatchMain()
