// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "ZoomItMac",
    platforms: [
        .macOS(.v13)
    ],
    targets: [
        .executableTarget(
            name: "ZoomItMac",
            path: "Sources",
            exclude: ["Info.plist", "ZoomItMac.entitlements"]
        )
    ]
)
