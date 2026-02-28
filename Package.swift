// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "Ghosty",
    platforms: [
        .macOS(.v26)
    ],
    products: [
        .executable(name: "Ghosty", targets: ["GhostyApp"])
    ],
    dependencies: [
        .package(url: "https://github.com/soffes/HotKey.git", from: "0.2.1"),
        .package(url: "https://github.com/pvieito/PythonKit.git", from: "0.0.1")
    ],
    targets: [
        .executableTarget(
            name: "GhostyApp",
            dependencies: ["HotKey", "PythonKit"],
            path: "Sources/GhostyApp",
            exclude: ["Info.plist"],
            resources: [
                .process("Resources")
            ]
        )
    ]
)
