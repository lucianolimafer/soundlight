// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "SoundLight",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "SoundLight", targets: ["SoundLight"])
    ],
    targets: [
        .executableTarget(
            name: "SoundLight",
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("CoreAudio"),
                .linkedFramework("CoreGraphics")
            ]
        )
    ]
)
