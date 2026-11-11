// swift-tools-version: 6.0
import PackageDescription
let package = Package(name: "GuideExport", platforms: [.macOS(.v14)],
  dependencies: [.package(path: "../../..")],
  targets: [.executableTarget(name: "GuideExport", dependencies: [.product(name: "OpenUISwiftUI", package: "openui"), .product(name: "OpenUILang", package: "openui")], path: "Sources", swiftSettings: [.swiftLanguageMode(.v5)])])
