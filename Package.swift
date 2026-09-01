// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "HDRezkaApp",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
        .tvOS(.v17),
        .visionOS(.v1)
    ],
    products: [
        .library(
            name: "HDRezkaCore",
            targets: ["HDRezkaCore"]
        ),
        .executable(
            name: "HDRezkaApp",
            targets: ["HDRezkaApp"]
        )
    ],
    dependencies: [],
    targets: [
        .target(
            name: "HDRezkaCore",
            dependencies: [],
            path: "Sources/HDRezkaCore"
        ),
        .executableTarget(
            name: "HDRezkaApp",
            dependencies: ["HDRezkaCore"],
            path: "Sources/HDRezkaApp"
        ),
        .testTarget(
            name: "HDRezkaCoreTests",
            dependencies: ["HDRezkaCore"],
            path: "Tests/HDRezkaCoreTests"
        )
    ]
)
