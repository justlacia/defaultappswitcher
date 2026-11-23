// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "DefaultAppSwitcher",
    defaultLocalization: "tr",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "DefaultAppSwitcherCore",
            targets: ["DefaultAppSwitcherCore"]
        ),
        .executable(
            name: "DefaultAppSwitcher",
            targets: ["DefaultAppSwitcher"]
        )
    ],
    targets: [
        .target(
            name: "DefaultAppSwitcherCore",
            linkerSettings: [
                .linkedLibrary("sqlite3"),
                .linkedFramework("Security"),
                .linkedFramework("CoreServices"),
                .linkedFramework("AppKit"),
                .linkedFramework("UniformTypeIdentifiers")
            ]
        ),
        .executableTarget(
            name: "DefaultAppSwitcher",
            dependencies: ["DefaultAppSwitcherCore"]
        ),
        .testTarget(
            name: "DefaultAppSwitcherTests",
            dependencies: ["DefaultAppSwitcherCore"]
        )
    ]
)
