import Foundation

typealias Tag = Int32

public struct CommandPattern {
    public typealias Element = (time: TimeInterval, size: Int)

    public static func custom(url: URL) throws -> Array<Element> {
        return try String(contentsOf: url).components(separatedBy: .newlines).compactMap {
            guard !$0.isEmpty else {
                return nil
            }

            let components = $0.components(separatedBy: .whitespaces)
            assert(components.count == 3)
            return (time: TimeInterval(components[1])!, size: Int(components[2])!)
        }
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

    public static func cbr(rate: Double, totalTime: Double = .infinity, size: Int) -> LazyMapSequence<StrideTo<Double>, Element> {
        let size = size, interval = Double(size) / rate
        return stride(from: 0, to: totalTime, by: interval).lazy.map { ($0, size) }
    }
}
