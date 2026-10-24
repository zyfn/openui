// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "OpenUIDemo",
    platforms: [.macOS(.v13)],
    products: [.executable(name: "OpenUIDemo", targets: ["OpenUIDemo"])],
    dependencies: [
        .package(path: "../../../packages/swift-lang"),
        .package(path: "../../../packages/swift-ui"),
    ],
    targets: [.executableTarget(name: "OpenUIDemo", dependencies: [
        .product(name: "OpenUILang", package: "swift-lang"),
        .product(name: "OpenUISwiftUI", package: "swift-ui"),
    ], swiftSettings: [.swiftLanguageMode(.v5)])]
)
