// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Launchpad",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "Launchpad", targets: ["Launchpad"])
    ],
    dependencies: [
        .package(url: "https://github.com/pointfreeco/swift-composable-architecture", from: "1.0.0")
    ],
    targets: [
        .executableTarget(
            name: "Launchpad",
            dependencies: [
                .product(name: "ComposableArchitecture", package: "swift-composable-architecture")
            ],
            path: "Launchpad"
        ),
        .testTarget(
            name: "LaunchpadTests",
            dependencies: [
                "Launchpad",
                .product(name: "ComposableArchitecture", package: "swift-composable-architecture")
            ],
            path: "LaunchpadTests"
        )
    ]
)