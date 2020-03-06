//
//  Outputs.swift
//  
//
//  Created by Natchanon Luangsomboon on 3/3/2563 BE.
//

import Foundation
import LNTCSVCoder
import ArgumentParser

struct OutputArguments: ParsableArguments {
    @Flag(name: .shortAndLong) var plot: Bool
    @Option(name: [.customShort("P"), .long], transform: URL.init(fileURLWithPath:)) var plottingPath: URL?

    mutating func set(commandURL: URL, id: Int) {
        if plot && plottingPath == nil {
            plottingPath = commandURL.deletingPathExtension().appendingPathComponent("\(id)")
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
