//
//  CommandArguments.swift
//  
//
//  Created by Natchanon Luangsomboon on 3/3/2563 BE.
//

import Foundation
import LNTCSVCoder
import ArgumentParser

struct CommandArguments: ParsableArguments {
    @Option() var duration: Double?
    @Option(default: 1000) var packetSize: Int

    @Flag(name: .shortAndLong) var plot: Bool
    @Option(name: [.customShort("P"), .long], transform: URL.init(fileURLWithPath:)) var plottingPath: URL?

    @Argument(transform: URL.init(fileURLWithPath:)) var commandURL: URL
    @Argument() var experimentationID: Int

    @Undecoded var command: Command

    mutating func validate() throws {
        let list = try JSONDecoder().decode([Command].self, from: Data(contentsOf: commandURL))
        guard list.indices ~= experimentationID else {
            print("id (\(experimentationID)) out of range (\(list.indices))")
            throw RunError.idOutOfRange
        }
        command = list[experimentationID]

        if duration == nil {
            duration = command.values.compactMap { $0.values.compactMap { $0.map { $0.endTime }.max() }.max() }.max()
        }

        if plot && plottingPath == nil {
            plottingPath = commandURL.deletingPathExtension().appendingPathComponent("\(experimentationID)")
        }
    }

    func register(port: Int, interval: TimeInterval, sizes: [Int], isInput: Bool) {
        if let url = plottingPath {
            let path = url.appendingPathComponent("\(port)").appendingPathExtension(isInput ? "in" : "out").path
            let entries = sizes.enumerated().map { offset, size in
                PlotPoint(time: interval * TimeInterval(offset), rate: Double(size * 8) / interval)
            }
            let data = try! CSVEncoder().encode(entries).data(using: .ascii)!

            FileManager.default.createFile(atPath: path, contents: data, attributes: nil)
        }
    }
}

extension FileHandle: TextOutputStream {
    public func write(_ string: String) {
        write(Data(string.utf8))
    }
}
