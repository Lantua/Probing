import Foundation
import LNTCSVCoder

typealias Tag = Int

public struct CommandPattern {
    public typealias Element = (time: TimeInterval, size: Int)

    public static func custom(url: URL) throws -> Array<Element> {
        struct Row: Codable {
            var time: TimeInterval, size: Int
        }
        let string = try String(contentsOf: url)
        return try CSVDecoder().decode(Row.self, from: string).map { ($0.time, $0.size) }
    }

    public struct PoissonIterator: IteratorProtocol {
        fileprivate let commandPerSecond: Double, size: Int

        fileprivate var time: TimeInterval

        public mutating func next() -> Element? {
            let currentTime = time
            time -= log(Double.random(in: 0...1)) / commandPerSecond
            return (currentTime, size)
        }
    }

    public static func poisson(rate: Double, size: Int) -> AnySequence<Element> {
        return AnySequence {
            PoissonIterator(commandPerSecond: rate / Double(size), size: size, time: 0)
        }
    }

    public static func cbr(rate: Double, size: Int) -> LazyMapSequence<StrideTo<Double>, Element> {
        let size = size, interval = Double(size) / rate
        return stride(from: 0, to: .infinity, by: interval).lazy.map { ($0, size) }
    }
}
