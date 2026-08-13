// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "YasIsland",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(
            name: "YasIsland",
            targets: ["AlcoveApp"]
        ),
        .library(
            name: "AlcoveKit",
            targets: ["AlcoveKit"]
        ),
        .executable(
            name: "YasIslandTests",
            targets: ["AlcoveTests"]
        )
    ],
    dependencies: [],
    targets: [
        .target(
            name: "AlcoveKit",
            dependencies: [],
            path: "Sources/AlcoveKit",
            swiftSettings: [
                .enableUpcomingFeature("StrictConcurrency"),
                .swiftLanguageMode(.v6)
            ]
        ),
        .executableTarget(
            name: "AlcoveApp",
            dependencies: ["AlcoveKit"],
            path: "Sources/AlcoveApp",
            swiftSettings: [
                .enableUpcomingFeature("StrictConcurrency"),
                .swiftLanguageMode(.v6)
            ]
        ),
        .executableTarget(
            name: "AlcoveTests",
            dependencies: ["AlcoveKit"],
            path: "Tests/AlcoveTests",
            swiftSettings: [
                .enableUpcomingFeature("StrictConcurrency"),
                .swiftLanguageMode(.v6)
            ]
        )
    ]
)
