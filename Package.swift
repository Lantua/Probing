// swift-tools-version:5.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Probing",
    platforms: [
        .macOS(.v10_12),
    ],
    products: [
        .library(name: "Probing", targets: ["Probing"]),
        .executable(name: "Forward", targets: ["Forward"]),
        .executable(name: "Run", targets: ["Run"]),
    ],
    dependencies: [
        // Dependencies declare other packages that this package depends on.
        // .package(url: /* package url */, from: "1.0.0"),
        .package(url: "https://github.com/IBM-Swift/BlueSocket", from: "1.0.0"),
        .package(url: "https://github.com/Lantua/CommonCoder", .revision("4064abd8b7fd4acfeada7d603f54484f8bee414e")),
        .package(url: "git@github.com:apple/swift-argument-parser.git", .exact("0.0.1")),
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages which this package depends on.
        .target(
            name: "Probing",
            dependencies: ["Socket", "LNTCSVCoder"]),
        .target(
            name: "Run",
            dependencies: ["Probing", "Socket", "ArgumentParser"]),
        .target(
            name: "Forward",
            dependencies: ["Probing", "Socket", "ArgumentParser"]),
        ]
)
