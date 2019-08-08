import Foundation

public struct DataTrace {
    var id: Tag, time: Date, size: Int
}

public protocol DataTraceOutputStream {
    func write(_: DataTrace)
    func finalize()
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

    public func finalize() {
        handle.synchronizeFile()
    }
}

public class StatsDataTraceOutputStream: DataTraceOutputStream {
    let startTime: Date, interval: Double
    var sizes: [Int] = []
    var callback: (Double, Double) -> ()

    public init(startTime: Date, interval: Double = 0.2, callback: @escaping (Double, Double) -> ()) {
        self.startTime = startTime
        self.interval = interval
        self.callback = callback
    }

    public func write(_ data: DataTrace) {
        let block = max(Int(data.time.timeIntervalSince(startTime) / interval), 0)
        if sizes.count <= block {
            sizes.append(contentsOf: repeatElement(0, count: block + 1 - sizes.count))
        }
        sizes[block] += data.size
    }

    public func finalize() {
        var rate = 0.0, cv = 0.0
        defer { callback(rate, cv) }

        let rates = sizes.dropLast().map { Double($0) * 8 / interval }
        guard !rates.isEmpty else {
            return 
        }

        let mean = rates.reduce(0, +) / Double(rates.count)
        let variance = rates.map { ($0 - mean) * ($0 - mean) }.reduce(0, +) / Double(rates.count)

        rate = mean
        cv = sqrt(variance) / mean
    }
}

