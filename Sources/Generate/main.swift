import Foundation

func cbr(rate: Double, maxSize: Int = 500, startTime: TimeInterval = 0, duration: Double? = nil) -> SendPattern {
    return SendPattern(type: "cbr", rate: rate, maxSize: maxSize, url: nil, startTime: startTime, duration: duration)
}

func command(port: Int32, pattern: SendPattern, packetSize: Int = 1000) -> Command {
    return Command(destination: "127.0.0.1", port: port, pattern: pattern, packetSize: packetSize)
}

struct Class {
    var port: Int32
    var patterns: [SendPattern]
}

let cbrs = stride(from: 1000_000_000, through: 1000_000_000, by: 1_000_000).dropFirst(2).map { cbr(rate: $0) }

let classes: [Class] = [
    .init(port: 10000, patterns: [cbr(rate: 100_000_000)]),
    .init(port: 10001, patterns: [cbr(rate: 100_000_000)]),
]

let minActiveCount = 2
let maxActiveCount = 3

var partial: [Command] = []
var result: [[Command]] = []
func walk(classes: ArraySlice<Class>) {
    guard partial.count < maxActiveCount,
        let current = classes.first else {
        if minActiveCount...maxActiveCount ~= partial.count {
            result.append(partial)
        }
        return
    }
    walk(classes: classes.dropFirst())
    for pattern in current.patterns {
        partial.append(command(port: current.port, pattern: pattern))
        defer { partial.removeLast() }

        walk(classes: classes.dropFirst())
    }
}

walk(classes: classes[...])
print("Total: \(result.count) cases")

let url = URL(fileURLWithPath: "test.json")
let data = try JSONEncoder().encode(result)
try data.write(to: url)
