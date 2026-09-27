// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "eye-rest",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "eye-rest", targets: ["eye-rest"])
    ],
    targets: [
        .executableTarget(
            name: "eye-rest",
            exclude: ["Info.plist"]
        ),
        .testTarget(
            name: "eye-restTests",
            dependencies: ["eye-rest"]
        ),
    ]
)
