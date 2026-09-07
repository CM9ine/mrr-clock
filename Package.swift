// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "MRRClockCore",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "MRRClockCore", targets: ["MRRClockCore"])
    ],
    targets: [
        .target(name: "MRRClockCore"),
        .testTarget(name: "MRRClockCoreTests", dependencies: ["MRRClockCore"])
    ]
)
