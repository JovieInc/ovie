// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Ovie",
    platforms: [
        .macOS(.v14),
    ],
    targets: [
        .executableTarget(
            name: "Ovie",
            path: "Sources/Ovie"
        ),
        .testTarget(
            name: "OvieTests",
            dependencies: ["Ovie"],
            path: "Tests/OvieTests"
        ),
    ]
)
