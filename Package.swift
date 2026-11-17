// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Taffy",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "Taffy",
            path: "Sources/Taffy"
        ),
        .testTarget(
            name: "TaffyTests",
            dependencies: ["Taffy"],
            path: "Tests/TaffyTests"
        ),
    ]
)
