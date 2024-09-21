// swift-tools-version:5.10

import PackageDescription

let package = Package(
    name: "sebbu-ts-ds",
    platforms: [.macOS("15.0"), .iOS("18.0")],
    products: [
        .library(
            name: "SebbuTSDS",
            targets: ["SebbuTSDS"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-atomics.git", from: "1.1.0"),
        //TODO: Use a version that includes HeapModule
        .package(url: "https://github.com/apple/swift-collections.git", branch: "main")
    ],
    targets: [
        .target(
            name: "SebbuTSDS",
            dependencies: [.product(name: "Atomics", package: "swift-atomics"),
                           .product(name: "DequeModule", package: "swift-collections"),
                           .product(name: "HeapModule", package: "swift-collections"),
                           "CSebbuTSDS"]),
        .target(name: "CSebbuTSDS"),
        .testTarget(
            name: "SebbuTSDSTests",
            dependencies: ["SebbuTSDS",
                           .product(name: "Atomics", package: "swift-atomics")]),
    ]
)
