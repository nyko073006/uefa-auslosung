// swift-tools-version: 5.10

import PackageDescription

let package = Package(
    name: "UEFAAuslosung",
    products: [
        .library(
            name: "DrawEngine",
            targets: ["DrawEngine"]
        )
    ],
    targets: [
        .target(
            name: "DrawEngine",
            path: "Packages/DrawEngine/Sources/DrawEngine"
        ),
        .testTarget(
            name: "DrawEngineTests",
            dependencies: ["DrawEngine"],
            path: "Tests/DrawEngineTests"
        )
    ]
)

