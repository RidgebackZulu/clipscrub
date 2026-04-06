// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "ClipScrub",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "ClipScrub",
            path: "Sources/ClipScrub"
        ),
        .testTarget(
            name: "ClipScrubTests",
            dependencies: ["ClipScrub"],
            path: "Tests/ClipScrubTests"
        ),
    ]
)
