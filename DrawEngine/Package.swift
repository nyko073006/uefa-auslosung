// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "DrawEngine",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "DrawEngine", targets: ["DrawEngine"]),
    ],
    targets: [
        .target(name: "DrawEngine"),
        .testTarget(name: "DrawEngineTests", dependencies: ["DrawEngine"]),
    ]
)
