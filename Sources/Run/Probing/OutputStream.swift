import Foundation

public struct DataTrace {
    public var time: Date, size: Int
}

public protocol DataTraceOutputStream {
    func write(_: DataTrace)
    func finalize()
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

