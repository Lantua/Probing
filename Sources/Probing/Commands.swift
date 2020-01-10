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

    public static func poisson(rate: Double, size: Int, start: TimeInterval, end: TimeInterval) -> AnySequence<Element> {
        return AnySequence {
            PoissonIterator(commandPerSecond: rate / Double(size), size: size, time: start, until: end)
        }
    }

    public static func cbr(rate: Double, size: Int, start: TimeInterval, end: TimeInterval) -> LazyMapSequence<StrideTo<Double>, Element> {
        let size = size, interval = Double(size) / rate
        return stride(from: start, to: end, by: interval).lazy.map { ($0, size) }
    }

    public static func merge(commands: [AnySequence<Element>]) -> AnySequence<Element> {
        return AnySequence {
            MergedIterator(iterators: commands.map { $0.makeIterator() })
        }
    }
}

private struct PoissonIterator: IteratorProtocol {
    public typealias Element = CommandPattern.Element

    fileprivate let commandPerSecond: Double, size: Int

    fileprivate var time: TimeInterval, until: TimeInterval

    public mutating func next() -> Element? {
        guard time < until else {
            return nil
        }
        let currentTime = time
        time -= log(Double.random(in: 0...1)) / commandPerSecond
        return (currentTime, size)
    }
}

private struct MergedIterator: IteratorProtocol {
    public typealias Element = CommandPattern.Element

    private var iterators: [(current: Element, iterator: AnyIterator<Element>)], time: TimeInterval

    init(iterators: [AnyIterator<Element>]) {
        self.iterators = iterators.compactMap { iterator in
            guard let current = iterator.next() else {
                return nil
            }
            return (current, iterator)
        }
        time = self.iterators.reduce(.infinity) { min($0, $1.current.time) }
    }

    public mutating func next() -> Element? {
        guard !iterators.isEmpty else {
            return nil
        }

        let currentTime = time

        var nextTime = TimeInterval.infinity, size = 0
        defer { time = nextTime }

        iterators = iterators.compactMap { arg in
            let (current, iterator) = arg
            if current.time == time {
                size += current.size

                guard let next = iterator.next() else {
                    return nil
                }
                nextTime = min(next.time, nextTime)
                return (next, iterator)
            }
            return arg
        }

        time = nextTime
        return (currentTime, size)
    }
}
