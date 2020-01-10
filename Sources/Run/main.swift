import Socket
import Probing
import Foundation
import LNTCSVCoder
import SPMUtility
import Basic

enum SendMode: String, StringEnumArgument, ArgumentKind {
    static var completion: ShellCompletion = .none

    case send, receive, forward, both
}

let parser = ArgumentParser(usage: "Probing Mechanism", overview: "Versatile Probing Mechanism for different structure")

let modeParser = parser.add(option: "--mode", shortName: "-m", kind: SendMode.self, usage: "Run mode [send, receive, forward, both (default)]")
let plottingParser = parser.add(option: "--plot", shortName: "-p", kind: PathArgument.self, usage: "Specify the path used for plotting")
let summarizeParser = parser.add(option: "--summarize", shortName: "-s", kind: PathArgument.self, usage: "Specify the path used for summary")

let commandURLParser = parser.add(positional: "Command File", kind: PathArgument.self, optional: false, usage: "JSON file for command")
let idParser = parser.add(positional: "Experimantation ID", kind: Int.self, optional: false, usage: "ID of the experiment")
let durationArgument = parser.add(positional: "Duration", kind: Int.self, optional: false, usage: "Duration of the experiment")

let result: ArgumentParser.Result
do {
    result = try parser.parse(.init(CommandLine.arguments.dropFirst()))
} catch {
    print(error)
    exit(-1)
}

guard let commandPath = result.get(commandURLParser)?.path,
    let id = result.get(idParser),
    let duration = result.get(durationArgument) else {
        let buffer = BufferedOutputByteStream()
        parser.printUsage(on: buffer)
        print(buffer.bytes)

        exit(-1)
}
let plottingPath = result.get(plottingParser)?.path
let summaryPath = result.get(summarizeParser)?.path

let mode = result.get(modeParser) ?? .both

let command: Command
do {
    let list = try JSONDecoder().decode([Command].self, from: NSData(contentsOfFile: commandPath.pathString)! as Data)
    guard list.indices ~= id else {
        print("id (\(id)) out of range (\(list.indices))")
        exit(-7)
    }
    command = list[id]
} catch {
    print("Invalid JSON file ", commandPath.basename, ": ", error)
    exit(-1)
}

let baseName: String = commandPath.basenameWithoutExt
let xxxx: Int = id as Int
let name = "\(baseName)-\(String(format: "%03d", xxxx))"

let runner = try Runner(command: command, plotting: plottingPath != nil, summarizing: summaryPath != nil, duration: Double(duration))
switch mode {
case .send:
    try runner.send()
case .receive:
    try runner.receive()
case .both:
    try runner.receive()
    try runner.send()
case .forward:
    fatalError("Unsupported mode")
}

runner.runningGroup.wait()

let stats = runner.stats, encoder: CSVEncoder
let values = stats.sorted(by: { $0.key < $1.key }).map { $0.value }

if let path = summaryPath?.pathString {
    if FileManager.default.fileExists(atPath: path) {
        encoder = CSVEncoder(options: .omitHeader)
    } else {
        FileManager.default.createFile(atPath: path, contents: nil)
        encoder = CSVEncoder()
    }

    guard var output = FileHandle(forWritingAtPath: path) else {
        fatalError("Can't write to \(path)")
    }
    output.seekToEndOfFile()
    try? encoder.encode(values, into: &output)
}

if let url = plottingPath?.asURL {
    var isDirectory: ObjCBool = false
    if !FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory) {
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true, attributes: nil)
    } else if !isDirectory.boolValue {
        fatalError("Plotting path is not a directory")
    }

    for (key, (sizes, interval)) in runner.sendingPlots {
        var path = try FileHandle(forWritingTo: url.appendingPathComponent("\(key)").appendingPathExtension("in"))
        let data = sizes.enumerated().map { offset, size in
            PlotPoint(id: offset, time: interval * TimeInterval(offset), rate: Double(size * 8) / interval)
        }
        try CSVEncoder().encode(data, into: &path)
    }
    for (key, (sizes, interval)) in runner.receivingPlots {
        var path = try FileHandle(forWritingTo: url.appendingPathComponent("\(key)").appendingPathExtension("in"))
        let data = sizes.enumerated().map { offset, size in
            PlotPoint(id: offset, time: interval * TimeInterval(offset), rate: Double(size * 8) / interval)
        }
        try CSVEncoder().encode(data, into: &path)
    }
}
