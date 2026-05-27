// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PaywallKit",
    platforms: [
        .iOS(.v17)
    ],
    products: [
        .library(name: "PaywallKit", targets: ["PaywallKit"])
    ],
    targets: [
        .target(
            name: "PaywallKit",
            path: "Sources/PaywallKit"
        )
    ]
)
