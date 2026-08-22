// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "NetflixNative",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(
            name: "NetflixNative",
            targets: ["NetflixNative"]
        )
    ],
    targets: [
        .executableTarget(
            name: "NetflixNative",
            path: "Sources"
        )
    ]
)
