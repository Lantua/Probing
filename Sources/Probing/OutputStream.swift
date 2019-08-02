import Foundation

public struct DataTrace {
    var id: Int32, time: Date, size: Int
}

public protocol DataTraceOutputStream {
    func write(_: DataTrace)
}

public class FileDataTraceOutputStream: DataTraceOutputStream {
    let handle: FileHandle, startTime: Date
    public init(url: URL, startTime: Date) throws {
        handle = try FileHandle(forWritingTo: url)
        self.startTime = startTime
    }

    public func write(_ data: DataTrace) {
        handle.write("\(data.id) \(data.time.timeIntervalSince(startTime)) \(data.size * 8)\n".data(using: .utf8)!)
    }

    deinit {
        handle.closeFile()
    }
}

public class StatsDataTraceOutputStream: DataTraceOutputStream {
    let startTime: Date, interval: Double
    var sizes: [Int] = []

    public init(startTime: Date, interval: Double = 0.2) {
        self.startTime = startTime
        self.interval = interval
    }

    public func write(_ data: DataTrace) {
        let block = max(Int(data.time.timeIntervalSince(startTime) / interval), 0)
        if sizes.count <= block {
            sizes.append(contentsOf: repeatElement(0, count: block + 1 - sizes.count))
        }
        sizes[block] += data.size
    }

    public func computeStats() -> (rate: Double, cv: Double) {
        let rates = sizes.dropLast().map { Double($0) * 8 / interval }

        guard !rates.isEmpty else {
            return (0, 0)
        }

        let mean = rates.reduce(0, +) / Double(rates.count)
        let variance = rates.map { ($0 - mean) * ($0 - mean) }.reduce(0, +) / Double(rates.count)

        let cv = sqrt(variance) / mean

        return (mean, cv)
    }
}

public class DataTraceSummaryOutputStream: DataTraceOutputStream {
    let handle: FileHandle, interval: Double

    var accumulated = 0, currentBlock = 0, startTime: Date

    public init(url: URL, interval: Double, startTime: Date) throws {
        handle = try FileHandle(forWritingTo: url)
        self.interval = interval
        self.startTime = startTime
    }

    private func print(block: Int, accumulated: Int) {
        handle.write("0 \(interval * Double(block)) \(Double(accumulated) * 8 / interval)\n".data(using: .utf8)!)
    }

    public func write(_ data: DataTrace) {
        let block = Int(data.time.timeIntervalSince(startTime) / interval)
        if block != currentBlock {
            print(block: currentBlock, accumulated: accumulated)
            if block - currentBlock > 1 {
                print(block: currentBlock + 1, accumulated: 0)
                if block - currentBlock > 2 {
                    print(block: block - 1, accumulated: 0)
                }
            }

            currentBlock = block
            accumulated = data.size
        } else {
            accumulated += data.size
        }
    }

    deinit {
        print(block: currentBlock, accumulated: accumulated)
        handle.closeFile()
    }
}

public struct StdDataTraceOutStream: DataTraceOutputStream {
    public func write(_ data: DataTrace) {
        print("\(data.id) \(data.time.timeIntervalSince1970) \(data.size)")
    }
}
