import Foundation

func cbr(rate: Double, maxSize: Int = 1000, startTime: TimeInterval = 0, duration: Double? = nil) -> SendPattern {
    return SendPattern(type: .cbr, rate: rate, url: nil, packetSize: maxSize, maxSize: maxSize, startTime: startTime, endTime: duration.map { $0 + startTime }, listeningPort: nil)
}

struct Class {
    var port: Int
    var patterns: [SendPattern]
}

let cbrs = stride(from: 000_000_000, through: 100_000_000, by: 50_000_000).dropFirst(2).map { cbr(rate: $0) }

let classes: [Class] = [
    .init(port: 10000, patterns: cbrs),
    .init(port: 10001, patterns: cbrs),
    .init(port: 10002, patterns: cbrs),
    .init(port: 10003, patterns: cbrs),
]

let minActiveCount = 2
let maxActiveCount = 4

var partial: [Int: SendPattern] = [:]
var result: [Command] = []
func walk(classes: ArraySlice<Class>) {
    guard partial.count < maxActiveCount,
        let current = classes.first else {
        if minActiveCount...maxActiveCount ~= partial.count {
            result.append(["127.0.0.1": partial])
        }
        return
    }
    walk(classes: classes.dropFirst())
    for pattern in current.patterns {
        partial[current.port] = pattern
        defer { partial[current.port] = nil }

        walk(classes: classes.dropFirst())
    }
}

walk(classes: classes[...])
print("Total: \(result.count) cases")

let url = URL(fileURLWithPath: "test.json")
let data = try JSONEncoder().encode(result)
try data.write(to: url)
