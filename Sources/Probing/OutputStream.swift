import Foundation

public struct DataTrace {
    var id: Int32, time: Date, size: Int
}

public protocol DataTraceOutputStream {
    func write(_: DataTrace)
}

public class FileDataTraceOutputStream: DataTraceOutputStream {
    let handle: FileHandle
    public init(url: URL) throws {
        handle = try FileHandle(forWritingTo: url)
    }

    public func write(_ data: DataTrace) {
        handle.write("\(data.id) \(data.time.timeIntervalSince1970) \(data.size)\n".data(using: .utf8)!)
    }

    deinit {
        handle.closeFile()
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

public class StdDataTraceOutStream: DataTraceOutputStream {
    public init() { }

    public func write(_ data: DataTrace) {
        print("\(data.id) \(data.time.timeIntervalSince1970) \(data.size)")
    }
}
