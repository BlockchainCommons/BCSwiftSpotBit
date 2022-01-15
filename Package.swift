// swift-tools-version:5.5
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "BCSwiftSpotBit",
    platforms: [
        .iOS(.v15),
        .macOS(.v12)
    ],
    products: [
        .library(
            name: "SpotBit",
            targets: ["SpotBit"]),
    ],
    dependencies: [
        .package(
            url: "https://github.com/WolfMcNally/WolfBase",
            from: "3.3.0"
        ),
        .package(
            url: "https://github.com/WolfMcNally/WolfAPI",
            from: "0.0.0"
        ),
        .package(
            url: "https://github.com/BlockchainCommons/BCSwiftTor",
            from: "1.0.0"
        ),
    ],
    targets: [
        .target(
            name: "SpotBit",
            dependencies: [
                .product(name: "Tor", package: "BCSwiftTor"),
                "WolfBase",
                "WolfAPI"
            ]),
        .testTarget(
            name: "SpotBitTests",
            dependencies: [
                "SpotBit",
                .product(name: "Tor", package: "BCSwiftTor"),
                "WolfBase",
                "WolfAPI"
            ]),
    ]
)
