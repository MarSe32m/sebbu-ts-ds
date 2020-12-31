// swift-tools-version:5.3

import PackageDescription

let package = Package(
    name: "sebbu-ts-ds",
    products: [
        .library(
            name: "SebbuTSDS",
            targets: ["SebbuTSDS"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-atomics.git", from: "0.0.2")
    ],
    targets: [
        .target(
            name: "SebbuTSDS",
            dependencies: [.product(name: "Atomics", package: "swift-atomics")]),
        .testTarget(
            name: "SebbuTSDSTests",
            dependencies: ["SebbuTSDS",
                           .product(name: "Atomics", package: "swift-atomics")]),
    ]
)
