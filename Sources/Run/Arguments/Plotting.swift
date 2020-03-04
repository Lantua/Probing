//
//  File.swift
//  
//
//  Created by Natchanon Luangsomboon on 3/3/2563 BE.
//

import Foundation
import LNTCSVCoder
import ArgumentParser

struct Plot {
    let url: URL

    init?(argument: PlotArgument, commandURL: URL, experimentationID: Int) throws {
        guard argument.plot || argument.plottingPath != nil else {
            return nil
        }

        url = argument.plottingPath ?? commandURL.deletingPathExtension().appendingPathComponent("\(experimentationID)")

        var isDirectory: ObjCBool = false
        if FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory) {
            guard isDirectory.boolValue else {
                throw RunError.invalidPlottingPath
            }
        } else {
            try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: false)
        }
    }

    func plot(port: Int, suffix: String, interval: TimeInterval, sizes: [Int]) {
        let path = url.appendingPathComponent("\(port)").appendingPathExtension(suffix).path
        let entries = sizes.enumerated().map { offset, size in
            PlotPoint(id: offset, time: interval * TimeInterval(offset), rate: Double(size * 8) / interval)
        }
        let data = try! CSVEncoder().encode(entries).data(using: .ascii)!

        FileManager.default.createFile(atPath: path, contents: data, attributes: nil)
    }
}
