import Foundation
import Socket
import ArgumentParser

struct Receive: ParsableCommand {
    @OptionGroup() var commandArguments: CommandArguments

    func run() throws {
        guard commandArguments.plottingURL != nil else {
            return
        }

        let startTime = Date(), runningGroup = DispatchGroup()
        let duration = commandArguments.duration!, packetSize = commandArguments.packetSize

        for spec in commandArguments.command.values {
            for (port, patterns) in spec where !patterns.isEmpty {
                let backlogSize = patterns.lazy.map { $0.burstSize }.reduce(0, +)
                let logger = StatsDataTraceOutputStream(startTime: startTime) { sizes, interval in
                    DispatchQueue.global(qos: .background).async(group: runningGroup) {
                        self.commandArguments.register(port: port, interval: interval, sizes: sizes, isInput: false)
                    }
                }

                DispatchQueue.global().async(group: runningGroup) {
                    do {
                        try listen(on: port, until: startTime + duration, packetSize: packetSize, backlogSize: 2 * backlogSize, group: runningGroup, logger: logger)
                    } catch {
                        print("Receiving error: \(error)")
                    }
                }
            }
        }

        runningGroup.wait()
    }
}

private func listen(on port: Int, until: Date, packetSize: Int, backlogSize: Int, group: DispatchGroup, logger: DataTraceOutputStream) throws {
    let socket = try Socket.create(family: .inet, type: .datagram, proto: .udp)
    try socket.setReadTimeout(value: 100)
    try socket.listen(on: port, maxBacklogSize: backlogSize)

    let buffer = UnsafeMutableRawPointer.allocate(byteCount: packetSize, alignment: 1)
    defer { buffer.deallocate() }
    
    while true {
        let size = try socket.readDatagram(into: buffer.assumingMemoryBound(to: CChar.self), bufSize: packetSize).bytesRead + headerSize
        
        guard until.timeIntervalSinceNow >= 0 else {
            break
        }
        guard size > headerSize else {
            // Timeout
            continue
        }
        
        logger.write(.init(time: Date(), size: size))
    }
    logger.write(.init(time: Date(), size: 0))
    logger.finalize()
}
