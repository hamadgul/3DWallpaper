// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "WallpaperApp",
    platforms: [.macOS(.v13)],
    targets: [
        // Thin runner — just wires up NSApplication
        .executableTarget(
            name: "WallpaperAppRunner",
            dependencies: ["WallpaperApp"],
            path: "Sources"
        ),
        // All business logic — importable by tests
        .target(
            name: "WallpaperApp",
            path: "src",
            swiftSettings: [
                .unsafeFlags(["-Xfrontend", "-warn-long-function-bodies=200"])
            ]
        ),
        .testTarget(
            name: "WallpaperAppTests",
            dependencies: ["WallpaperApp"],
            path: "tests"
        ),
    ]
)
