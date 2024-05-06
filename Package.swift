// swift-tools-version:5.3
import PackageDescription

let package = Package(
    name: "OpenAPIGenerator",
    platforms: [ .macOS(.v10_14)],
    products: [
        .executable(name: "OpenAPIGenerator", targets: ["OpenAPIGenerator"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser", .upToNextMajor(from: "1.0.0")),
    ],
    targets: [
        .target(name: "OpenAPIGenerator", dependencies: [.product(name: "ArgumentParser", package: "swift-argument-parser"),], path: "OpenAPIGenerator"),
    ]
)
