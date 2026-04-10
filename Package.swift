// swift-tools-version: 6.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "dnsguard",
    platforms: [
        .macOS(.v12),
    ],
    dependencies: [
        .package(url: "https://github.com/wadetregaskis/NetworkInterfaceInfo.git", from: "5.1.2"),
    ],
    targets: [
        .executableTarget(
            name: "dnsguard",
            dependencies: [
                .product(name: "NetworkInterfaceChangeMonitoring", package: "networkinterfaceinfo")
            ],
        ),
    ],
    swiftLanguageModes: [.v6]
)
