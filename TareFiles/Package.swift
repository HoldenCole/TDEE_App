// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "TareFiles",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
    ],
    products: [
        .library(name: "TareFiles", targets: ["TareFiles"]),
    ],
    dependencies: [
        .package(path: "../TareEngine"),
        .package(url: "https://github.com/weichsel/ZIPFoundation.git", from: "0.9.19"),
    ],
    targets: [
        .target(
            name: "TareFiles",
            dependencies: [
                .product(name: "TareEngine", package: "TareEngine"),
                .product(name: "ZIPFoundation", package: "ZIPFoundation"),
            ],
            path: "Sources/TareFiles"
        ),
        .testTarget(
            name: "TareFilesTests",
            dependencies: ["TareFiles"],
            path: "Tests/TareFilesTests"
        ),
    ],
    swiftLanguageVersions: [.v5]
)
