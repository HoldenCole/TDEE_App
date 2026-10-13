// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "TareEngine",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
    ],
    products: [
        .library(name: "TareEngine", targets: ["TareEngine"]),
    ],
    targets: [
        .target(
            name: "TareEngine",
            path: "Sources/TareEngine"
        ),
        .testTarget(
            name: "TareEngineTests",
            dependencies: ["TareEngine"],
            path: "Tests/TareEngineTests"
        ),
    ],
    swiftLanguageVersions: [.v5]
)
