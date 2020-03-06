//
//  SendReceive.swift
//  
//
//  Created by Natchanon Luangsomboon on 3/3/2563 BE.
//

import Foundation
import Socket
import ArgumentParser

struct SendReceive: ParsableCommand {
    @OptionGroup() var outputArguments: OutputArguments
    @OptionGroup() var commandArguments: CommandArguments

    func run() throws {
        let send = Send(outputArguments: _outputArguments, commandArguments: _commandArguments)
        let receive = Receive(outputArguments: _outputArguments, commandArguments: _commandArguments)

        let group = DispatchGroup()

        DispatchQueue.global().async(group: group) {
            try! send.run()
        }
        DispatchQueue.global().async(group: group) {
            try! receive.run()
        }

        group.wait()
    }
}
