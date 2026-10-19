// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "OpenUIDemo",
    platforms: [.macOS(.v13)],
    products: [.executable(name: "OpenUIDemo", targets: ["OpenUIDemo"])],
    dependencies: [
        .package(path: "../../../packages/openui-lang"),
        .package(path: "../../../packages/openui-swiftui"),
    ],
    targets: [.executableTarget(name: "OpenUIDemo", dependencies: [
        .product(name: "OpenUILang", package: "openui-lang"),
        .product(name: "OpenUISwiftUI", package: "openui-swiftui"),
    ], swiftSettings: [.swiftLanguageMode(.v5)])]
)
