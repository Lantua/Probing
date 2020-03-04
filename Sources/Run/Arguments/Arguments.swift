//
//  Arguments.swift
//  
//
//  Created by Natchanon Luangsomboon on 4/3/2563 BE.
//

import Foundation
import ArgumentParser

struct RunnerArgument: ParsableArguments {
    @OptionGroup() var plot: PlotArgument
    @OptionGroup() var summary: SummaryArgument
    @OptionGroup() var experimentSpec: CommandArgument
    @Argument() var duration: Double
}

struct CommandArgument: ParsableArguments {
    @Argument(transform: URL.init(fileURLWithPath:)) var commandURL: URL
    @Argument() var experimentationID: Int

    var name: String {
        let baseName = commandURL.deletingPathExtension().lastPathComponent
        return "\(baseName)-\(String(format: "%03d", experimentationID as Int))"
    }
}

struct PlotArgument: ParsableArguments {
    @Flag() var plot: Bool
    @Option(transform: URL.init(fileURLWithPath:)) var plottingPath: URL?
}

struct SummaryArgument: ParsableArguments {
    @Flag(name: .customLong("summarize")) var summarizing: Bool
    @Option(transform: URL.init(fileURLWithPath:)) var summaryPath: URL?
}
