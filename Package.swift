// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "MyTodayKit",
    platforms: [.macOS(.v26)],
    products: [
        .library(name: "MyTodayKit", targets: ["MyTodayKit"]),
    ],
    targets: [
        .target(
            name: "MyTodayKit",
            swiftSettings: [
                .swiftLanguageMode(.v5),
                .enableUpcomingFeature("MemberImportVisibility"),
                .unsafeFlags(["-default-isolation", "MainActor"]),
            ]
        ),
        .testTarget(
            name: "MyTodayKitTests",
            dependencies: ["MyTodayKit"],
            swiftSettings: [
                .swiftLanguageMode(.v5),
                .enableUpcomingFeature("MemberImportVisibility"),
                .unsafeFlags(["-default-isolation", "MainActor"]),
            ]
        ),
    ]
)
