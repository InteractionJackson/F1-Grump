// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "TrackAlignServer",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "TrackAlignServer", targets: ["TrackAlignServer"])
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-nio.git", from: "2.56.0")
    ],
    targets: [
        .executableTarget(
            name: "TrackAlignServer",
            dependencies: [
                .product(name: "NIO", package: "swift-nio"),
                .product(name: "NIOHTTP1", package: "swift-nio")
            ],
            path: "Sources"
        )
    ]
)

