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
        .package(url: "https://github.com/apple/swift-collections.git", from: "1.1.0")
    ],
    targets: [
        .target(
            name: "SebbuTSDS",
            dependencies: [.product(name: "DequeModule", package: "swift-collections"),
                           .product(name: "HeapModule", package: "swift-collections")],
            swiftSettings: [.enableExperimentalFeature("Extern"),
                            .enableExperimentalFeature("BuiltinModule")]),
        .testTarget(
            name: "SebbuTSDSTests",
            dependencies: ["SebbuTSDS"]),
    ]
)
