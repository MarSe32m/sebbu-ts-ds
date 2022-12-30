// swift-tools-version:5.5

import PackageDescription

let package = Package(
    name: "sebbu-ts-ds",
    platforms: [.macOS(.v10_12), .iOS(.v10)],
    products: [
        .library(
            name: "SebbuTSDS",
            targets: ["SebbuTSDS"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-atomics.git", .branch("main")),
        .package(url: "https://github.com/apple/swift-collections.git", .branch("main"))
    ],
    targets: [
        .target(
            name: "SebbuTSDS",
            dependencies: [.product(name: "Atomics", package: "swift-atomics", condition: .when(platforms: [.iOS, .macOS, .tvOS, .watchOS, .linux])),
                           .product(name: "DequeModule", package: "swift-collections"),
                           .product(name: "HeapModule", package: "swift-collections"),
                           "CSebbuTSDS"]),
        .target(name: "CSebbuTSDS"),
        .testTarget(
            name: "SebbuTSDSTests",
            dependencies: ["SebbuTSDS",
                           .product(name: "Atomics", package: "swift-atomics", condition: .when(platforms: [.iOS, .macOS, .tvOS, .watchOS, .linux]))]),
    ]
)
