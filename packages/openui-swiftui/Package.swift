// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "OpenUISwiftUI",
    platforms: [.macOS(.v12), .iOS(.v15)],
    products: [
        .library(name: "OpenUISwiftUI", targets: ["OpenUISwiftUI"]),
    ],
    dependencies: [
        .package(path: "../openui-lang"),
    ],
    targets: [
        .target(
            name: "OpenUISwiftUI",
            dependencies: [.product(name: "OpenUILang", package: "openui-lang")],
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .testTarget(
            name: "OpenUISwiftUITests",
            dependencies: ["OpenUISwiftUI"],
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
    ]
)
