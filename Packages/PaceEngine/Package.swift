// swift-tools-version: 6.0
//
// The Anchor & Impulse pace engine, ported from PaceEngine/pace_engine.py (the source of
// truth). Pure logic, Foundation only, so its tests run with `swift test` in seconds.

import PackageDescription

let package = Package(
    name: "PaceEngine",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "PaceEngine", targets: ["PaceEngine"]),
    ],
    targets: [
        .target(name: "PaceEngine"),
        .testTarget(
            name: "PaceEngineTests",
            dependencies: ["PaceEngine"],
            resources: [.copy("Resources/golden_vectors.json")]
        ),
    ]
)
