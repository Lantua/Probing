import Foundation
import LNTCSVCoder

public enum CommandPattern {
    public typealias Element = (time: TimeInterval, size: Int)

    public static func poisson(rate: Double, size: Int, start: TimeInterval, end: TimeInterval) -> AnySequence<Element> {
        return AnySequence {
            PoissonIterator(commandPerSecond: rate / Double(size), size: size, time: start, until: end)
        }
    }

    public static func cbr(rate: Double, size: Int, start: TimeInterval, end: TimeInterval) -> LazyMapSequence<StrideTo<Double>, Element> {
        let size = size, interval = Double(size) / rate
        return stride(from: start, to: end, by: interval).lazy.map { ($0, size) }
    }

    public static func merge(commands: [AnySequence<Element>], until end: TimeInterval) -> AnySequence<Element> {
        if commands.count == 1 {
            return commands.first!
        }
        return AnySequence {
            MergedIterator(iterators: commands.map { $0.makeIterator() }, until: end)
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
    private let end: TimeInterval

    init(iterators: [AnyIterator<Element>], until: TimeInterval) {
        self.iterators = iterators.compactMap { iterator in
            guard let current = iterator.next() else {
                return nil
            }
            return (current, iterator)
        }
        time = self.iterators.reduce(.infinity) { min($0, $1.current.time) }
        end = until
    }

    public mutating func next() -> Element? {
        guard !iterators.isEmpty else {
            return nil
        }

        let currentTime = time
        var size = 0

        iterators = iterators.compactMap {
            let (current, iterator) = $0
            if current.time == currentTime {
                size += current.size

                guard let next = iterator.next() else {
                    return nil
                }
                return (next, iterator)
            }
            return $0
        }

        if let nextTime = iterators.lazy.map({ $0.current.time }).min(), nextTime < end {
            time = nextTime
        } else {
            iterators = []
        }

        return (currentTime, size)
    }
}
