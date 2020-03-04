import Socket
import Probing
import Foundation
import LNTCSVCoder

import ArgumentParser

enum RunError: Error {
    case idOutOfRange, invalidPlottingPath
}

struct Run: ParsableCommand {
    static var configuration = CommandConfiguration(subcommands: [Send.self, Receive.self, SendReceive.self, Forward.self])
}

Run.main()
