//
//  File.swift
//  
//
//  Created by Natchanon Luangsomboon on 4/3/2563 BE.
//

import Foundation
import ArgumentParser

extension Command {
    init(argument: CommandArgument) throws {
        let list = try JSONDecoder().decode([Command].self, from: Data(contentsOf: argument.commandURL))
        guard list.indices ~= argument.experimentationID else {
            print("id (\(argument.experimentationID)) out of range (\(list.indices))")
            throw RunError.idOutOfRange
        }
        self = list[argument.experimentationID]
    }
}
