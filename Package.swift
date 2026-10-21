// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "Vincenty",
    platforms: [.iOS(.v13), .macOS(.v11)],
    products: [
        .library(
            name: "Vincenty",
            targets: ["Vincenty"]
        )
    ],
    targets: [
        .target(name: "Vincenty"),
        .testTarget(
            name: "VincentyTests",
            dependencies: ["Vincenty"]
        )
    ]
)
