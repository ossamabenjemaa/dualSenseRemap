// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "DualSenseRemap",
    platforms: [
        .macOS(.v13)
    ],
    targets: [
        .executableTarget(
            name: "DualSenseRemap",
            path: "Sources/DualSenseRemap"
        )
    ]
)
