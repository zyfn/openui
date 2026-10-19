// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "OpenUILang",
    platforms: [.macOS(.v12), .iOS(.v15)],
    products: [
        .library(name: "OpenUILang", targets: ["OpenUILang"]),
    ],
    targets: [
        .target(
            name: "OpenUILang",
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .testTarget(
            name: "OpenUILangTests",
            dependencies: ["OpenUILang"],
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
    ]
)
