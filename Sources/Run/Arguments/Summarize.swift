//
//  File.swift
//  
//
//  Created by Natchanon Luangsomboon on 4/3/2563 BE.
//

import Foundation
import ArgumentParser

import LNTCSVCoder

struct Summary {
    let name: String, path: URL
    var summary: [Int: Stats] = [:]

    init?(_ arg: SummaryArgument, commandURL: URL) {
        guard arg.summarizing || arg.summaryPath != nil else {
            return nil
        }

        path = arg.summaryPath ?? commandURL.deletingPathExtension().appendingPathExtension("csv")
        name = commandURL.deletingPathExtension().lastPathComponent
    }

    mutating func register(port: Int, stats: Stats) {
        summary[port, default: Stats(name: name, port: port)] += stats
    }

    func summarize() throws {
        let values = summary.values.sorted(by: { $0.name < $1.name })
        let encoder: CSVEncoder

        if FileManager.default.fileExists(atPath: path.relativeString) {
            encoder = CSVEncoder(options: .omitHeader)
        } else {
            FileManager.default.createFile(atPath: path.relativeString, contents: nil)
            encoder = CSVEncoder()
        }

        var output = try FileHandle(forWritingTo: path)
        output.seekToEndOfFile()
        try encoder.encode(values, into: &output)
    }
}

extension FileHandle: TextOutputStream {
    public func write(_ string: String) {
        write(Data(string.utf8))
    }
}
