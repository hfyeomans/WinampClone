// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "WinAmpPlayer",
    platforms: [
        .macOS(.v14)
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
            exclude: ["Core/AudioEngine/Conversion/README.md"],
            resources: [
                .process("Shaders")
            ]
        ),
        .testTarget(
            name: "WinAmpPlayerTests",
            dependencies: ["WinAmpPlayer"]
        )
    ]
)