// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "ClaudeTokenWidget",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "ClaudeTokenWidget",
            path: "Sources/ClaudeTokenWidget"
        )
    ]
)
