// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "AnonymousSimpleStats",
    platforms: [.iOS(.v15), .tvOS(.v15), .visionOS(.v1), .macOS(.v12)],
    products: [
        .library(name: "AnonymousSimpleStats", targets: ["AnonymousSimpleStats"])
    ],
    targets: [
        .target(
            name: "AnonymousSimpleStats",
            resources: [.copy("PrivacyInfo.xcprivacy")]
        ),
        .testTarget(
            name: "AnonymousSimpleStatsTests",
            dependencies: ["AnonymousSimpleStats"]
        )
    ]
)
