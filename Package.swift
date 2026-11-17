// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Tabby",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "Tabby",
            path: "Sources/Tabby"
        )
    ]
)
