// swift-tools-version:4.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Probing",
    products: [
        .library(name: "Probing", type: .dynamic, targets: ["Probing"]),
        .executable(name: "Run", targets: ["Run"]),
        .executable(name: "Generate", targets: ["Generate"]),
    ],
    dependencies: [
        // Dependencies declare other packages that this package depends on.
        // .package(url: /* package url */, from: "1.0.0"),
        .package(url: "https://github.com/IBM-Swift/BlueSocket.git", from: "1.0.0"),
        .package(url: "git@github.com:Lantua/CommonCoder.git", .branch("master"))
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages which this package depends on.
        .target(
            name: "Probing",
            dependencies: ["Socket", "CSVCoder"]),
        .target(
            name: "Run",
            dependencies: ["Probing", "Socket"]),
        .target(
            name: "Generate",
            dependencies: ["Probing"]),
        ]
)
