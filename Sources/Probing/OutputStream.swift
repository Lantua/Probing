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

public struct PrintOutputStream: DataTraceOutputStream {
    let prefix: String, startTime: Date

    public init(prefix: String, startTime: Date) {
        self.prefix = prefix
        self.startTime = startTime
    }

    public func write(_ data: DataTrace) {
        print("\(prefix) \(data.id) \(data.time.timeIntervalSince(startTime)) \(data.size * 8)")
    }

    public func finalize() { }
}

public class StatsDataTraceOutputStream: DataTraceOutputStream {
    let startTime: Date, interval: Double
    var sizes: [Int] = []
    var callback: ([Int], Double) -> ()

    public init(startTime: Date, interval: Double = 0.2, callback: @escaping ([Int], Double) -> ()) {
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
        callback(sizes, interval)
    }
}

