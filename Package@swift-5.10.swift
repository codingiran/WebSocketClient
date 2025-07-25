// swift-tools-version: 5.10
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "WebSocketClient",
    platforms: [
        .iOS(.v13),
        .macOS(.v10_15),
        .tvOS(.v13),
        .watchOS(.v6),
        .macCatalyst(.v13),
        .visionOS(.v1),
    ],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "WebSocketClient",
            targets: ["WebSocketClient"]
        ),
        .library(
            name: "URLSessionWebSocketBackend",
            targets: ["URLSessionWebSocketBackend"]
        ),
    ],
    dependencies: [
        // Dependencies declare other packages that this package depends on.
        .package(url: "https://github.com/codingiran/AsyncTimer.git", from: "0.0.4"),
        .package(url: "https://github.com/codingiran/NetworkPathMonitor.git", from: "0.1.2"),
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "WebSocketClient",
            dependencies: [
                "AsyncTimer",
                "NetworkPathMonitor",
            ],
            path: "WebSocketClient/Sources",
            resources: [.copy("PrivacyInfo.xcprivacy")]
        ),
        .target(
            name: "URLSessionWebSocketBackend",
            dependencies: [
                "WebSocketClient",
            ],
            path: "URLSessionWebSocketBackend/Sources",
            resources: [.copy("PrivacyInfo.xcprivacy")]
        ),
        .testTarget(
            name: "WebSocketClientTests",
            dependencies: [
                "WebSocketClient",
                "URLSessionWebSocketBackend",
            ],
            path: "WebSocketClientTests/Sources"
        ),
    ],
    swiftLanguageVersions: [.v5]
)
