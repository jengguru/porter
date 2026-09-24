// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Porter",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "Porter", targets: ["Porter"]),
    ],
    targets: [
        // Pure logic: no AppKit, everything behind protocols so it can be unit-tested.
        .target(name: "PorterCore"),
        // The menu bar app itself (AppKit status item + SwiftUI settings).
        .executableTarget(name: "Porter", dependencies: ["PorterCore"]),
        .testTarget(name: "PorterCoreTests", dependencies: ["PorterCore"]),
    ]
)
