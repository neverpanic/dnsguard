// swift-tools-version: 6.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "dnsguard",
    platforms: [
        .macOS(.v13),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-log", from: "1.6.0"),
    ],
    targets: [
        .executableTarget(
            name: "dnsguard",
            dependencies: [
                .product(name: "Logging", package: "swift-log"),
            ],
        ),
    ],
    swiftLanguageModes: [.v6]
)
