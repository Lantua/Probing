//
//  Arguments.swift
//  
//
//  Created by Natchanon Luangsomboon on 4/3/2563 BE.
//

import Foundation
import ArgumentParser

struct CommandArguments: ParsableArguments {
    @Argument(transform: URL.init(fileURLWithPath:)) var commandURL: URL
    @Argument() var experimentationID: Int
    @Argument() var duration: Double

    @Option(default: 1000) var packetSize: Int

    @Undecoded var command: Command

    mutating func validate() throws {
        let list = try JSONDecoder().decode([Command].self, from: Data(contentsOf: commandURL))
        guard list.indices ~= experimentationID else {
            print("id (\(experimentationID)) out of range (\(list.indices))")
            throw RunError.idOutOfRange
        }
        command = list[experimentationID]
    }

    var name: String {
        let baseName = commandURL.deletingPathExtension().lastPathComponent
        return "\(baseName)-\(String(format: "%03d", experimentationID as Int))"
    }
}

