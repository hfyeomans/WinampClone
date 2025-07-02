// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "WinAmpPlayer",
    platforms: [
        .macOS(.v15)
    ],
    products: [
        .executable(
            name: "WinAmpPlayer",
            targets: ["WinAmpPlayer"]
        )
    ],
    dependencies: [
        // Add any external dependencies here
    ],
    targets: [
        .executableTarget(
            name: "WinAmpPlayer",
            dependencies: [],
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "WinAmpPlayerTests",
            dependencies: ["WinAmpPlayer"]
        )
    ]
)