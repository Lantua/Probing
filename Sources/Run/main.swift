import Socket
import Probing
import Foundation
import LNTCSVCoder

import ArgumentParser

enum RunError: Error {
    case idOutOfRange, plottingNotToDirectory, unsupportedMode
}

enum SendMode: String, ExpressibleByArgument {
    case send, receive, forward, both
}

struct Run: ParsableCommand {
    @Option(default: SendMode.both) var mode: SendMode
    @Option(name: .customLong("plot"), transform: URL.init(fileURLWithPath:)) var plottingPath: URL?
    @Option(name: .customLong("summary-path"), transform: URL.init(fileURLWithPath:)) var summaryPath: URL?

    @Argument(transform: URL.init(fileURLWithPath:)) var commandURL: URL
    @Argument() var experimentationID: Int
    @Argument() var duration: Double

    func run() throws {
        let command: Command
        do {
            let list = try JSONDecoder().decode([Command].self, from: Data(contentsOf: commandURL))
            guard list.indices ~= experimentationID else {
                print("id (\(experimentationID)) out of range (\(list.indices))")
                throw RunError.idOutOfRange
            }
            command = list[experimentationID]
        }

        let baseName = commandURL.deletingPathExtension().lastPathComponent
        let name = "\(baseName)-\(String(format: "%03d", experimentationID as Int))"

        let runner = try Runner(command: command, plotting: plottingPath != nil, summarizing: summaryPath != nil, duration: Double(duration), name: name)
        switch mode {
        case .send:
            try runner.send()
        case .receive:
            try runner.receive()
        case .both:
            try runner.receive()
            try runner.send()
        case .forward:
            throw RunError.unsupportedMode
        }

        runner.runningGroup.wait()

        try summarize(runner)
        try plot(runner)
    }

    func summarize(_ runner: Runner) throws {
        guard let summaryPath = summaryPath else {
            return
        }

        let values = runner.stats.sorted(by: { $0.key < $1.key }).map { $0.value }
        let encoder: CSVEncoder

        if FileManager.default.fileExists(atPath: summaryPath.relativeString) {
            encoder = CSVEncoder(options: .omitHeader)
        } else {
            FileManager.default.createFile(atPath: summaryPath.relativeString, contents: nil)
            encoder = CSVEncoder()
        }

        var output = try FileHandle(forWritingTo: summaryPath)
        output.seekToEndOfFile()
        try encoder.encode(values, into: &output)
    }

    func plot(_ runner: Runner) throws {
        guard let url = plottingPath else {
            return
        }

        var isDirectory: ObjCBool = false
        if !FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory) {
            try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true, attributes: nil)
        } else if !isDirectory.boolValue {
            throw RunError.plottingNotToDirectory
        }

        for (key, (sizes, interval)) in runner.sendingPlots {
            let path = url.appendingPathComponent("\(key)").appendingPathExtension("in").path
            let entries = sizes.enumerated().map { offset, size in
                PlotPoint(id: offset, time: interval * TimeInterval(offset), rate: Double(size * 8) / interval)
            }
            let data = try CSVEncoder().encode(entries).data(using: .ascii)!

            FileManager.default.createFile(atPath: path, contents: data, attributes: nil)
        }
        for (key, (sizes, interval)) in runner.receivingPlots {
            let path = url.appendingPathComponent("\(key)").appendingPathExtension("out").path
            let entries = sizes.enumerated().map { offset, size in
                PlotPoint(id: offset, time: interval * TimeInterval(offset), rate: Double(size * 8) / interval)
            }
            let data = try CSVEncoder().encode(entries).data(using: .ascii)!

            FileManager.default.createFile(atPath: path, contents: data, attributes: nil)
        }
    }
}

Run.main()
