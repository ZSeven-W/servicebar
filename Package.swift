// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "ServiceBar",
    platforms: [
        .macOS(.v13)
    ],
    targets: [
        .executableTarget(
            name: "ServiceBar",
            path: "Sources/ServiceBar",
            exclude: ["Assets.xcassets", "Resources"]
        )
    ]
)
