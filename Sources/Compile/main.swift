import Foundation
import LNTCSVCoder
import ArgumentParser

import LNTProbeCoding

struct Main: ParsableCommand {
    @Argument(transform: URL.init(fileURLWithPath:)) var folderURLs: [URL]
    @Option() var scale: Double?

    func run() throws {
        let scale = self.scale ?? 1000_000

        for folderURL in folderURLs {
            let files = try FileManager.default.contentsOfDirectory(atPath: folderURL.path)
            let outputPath = folderURL.appendingPathExtension("csv").path

            let decoder = CSVDecoder(), encoder = CSVEncoder()

            var values: [Double: [String: Double]] = [:]
            var maxTime: [String: Double] = [:]

            for file in files {
                print("Processing \(file)")
                let path = folderURL.appendingPathComponent(file).path
                guard let raw = FileManager.default.contents(atPath: path) else {
                    continue
                }

                let content = String(data: raw, encoding: .ascii)!

                guard let trace = try? decoder.decode(TraceRow.self, from: content) else {
                    continue
                }

                for row in trace {
                    values[row.time, default: [:]][file] = row.rate / scale
                }

                maxTime[file] = trace.last?.time
            }

            var defaultValue = maxTime.mapValues { _ in Double.nan }

            let sorted: [[String: Double]] = values.sorted { $0.key < $1.key }.map {
                var (time, value) = $0

                defaultValue.merge(value) { $1 }
                for file in defaultValue.keys where maxTime[file]! == time {
                    defaultValue[file] = .nan
                }

                value["time"] = time
                value.merge(defaultValue) { older, _ in older }
                return value
            }

            let converted = try encoder.encode(sorted)
            FileManager.default.createFile(atPath: outputPath, contents: converted.data(using: .ascii)!)
        }
    }
}

Main.main()
