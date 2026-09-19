// swift-tools-version: 6.2

import PackageDescription

/// Matches the settings the charts were built with: UI code on the main actor by default, with
/// approachable concurrency. Model types opt out with `nonisolated`, so they can be built anywhere.
let swiftSettings: [SwiftSetting] = [
    .swiftLanguageMode(.v5),
    .defaultIsolation(MainActor.self),
    .enableUpcomingFeature("InferIsolatedConformances"),
    .enableUpcomingFeature("NonisolatedNonsendingByDefault"),
    .enableUpcomingFeature("MemberImportVisibility"),
]

let package = Package(
    name: "QuickCharts",
    platforms: [.iOS(.v18)],
    products: [
        .library(name: "QuickCharts", targets: ["QuickCharts"]),
    ],
    targets: [
        .target(name: "QuickCharts", swiftSettings: swiftSettings),
        .testTarget(name: "QuickChartsTests", dependencies: ["QuickCharts"], swiftSettings: swiftSettings),
    ]
)
