// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "SetterStats",
    platforms: [.iOS(.v16)],
    products: [
        .library(name: "SetterStatsCore", targets: ["SetterStatsCore"])
    ],
    targets: [
        .target(name: "SetterStatsCore"),
        .testTarget(name: "SetterStatsTests", dependencies: ["SetterStatsCore"])
    ]
)
