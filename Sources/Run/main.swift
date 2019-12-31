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
let plottingParser = parser.add(option: "--plot", shortName: "-p", kind: Bool.self, usage: "Specify the id of the argument")

let commandURLParser = parser.add(positional: "Command File", kind: PathArgument.self, optional: false, usage: "JSON file for command")
let outputURLParser = parser.add(positional: "Output File", kind: PathArgument.self, optional: false, usage: "Output files directory")
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
    let outputPath = result.get(outputURLParser)?.path.pathString,
    let id = result.get(idParser),
    let duration = result.get(durationArgument) else {
        let buffer = BufferedOutputByteStream()
        parser.printUsage(on: buffer)
        print(buffer.bytes)

        exit(-1)
}
let plotting = result.get(plottingParser) ?? false
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

let runner = Runner(command: command, plotting: plotting, duration: Double(duration))
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

if FileManager.default.fileExists(atPath: outputPath) {
    encoder = CSVEncoder(options: .omitHeader)
} else {
    FileManager.default.createFile(atPath: outputPath, contents: nil)
    encoder = CSVEncoder()
}

guard var output = FileHandle(forWritingAtPath: outputPath) else {
    print("Can't write to \(outputPath)")
    exit(0)
}
output.seekToEndOfFile()
try? encoder.encode(values, into: &output)
