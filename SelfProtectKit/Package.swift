// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "SelfProtectKit",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "SelfProtectKit", targets: ["SelfProtectKit"])
    ],
    targets: [
        .target(name: "SelfProtectKit")
    ]
)
