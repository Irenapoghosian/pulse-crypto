// swift-tools-version: 5.10
import PackageDescription

/// Pulse is split into small modules with one-way dependencies:
///
///   Features ──▶ Domain ◀── DataLayer ──▶ Networking
///      │                       (CoinGecko, cache, SwiftData)
///      └──────▶ DesignSystem
///
/// Features never import DataLayer or each other; the app and widget targets wire everything together.
let package = Package(
    name: "PulseKit",
    platforms: [.iOS(.v17)],
    products: [
        .library(name: "Localization", targets: ["Localization"]),
        .library(name: "Domain", targets: ["Domain"]),
        .library(name: "Networking", targets: ["Networking"]),
        .library(name: "DataLayer", targets: ["DataLayer"]),
        .library(name: "DesignSystem", targets: ["DesignSystem"]),
        .library(name: "MarketsFeature", targets: ["MarketsFeature"]),
        .library(name: "CoinDetailFeature", targets: ["CoinDetailFeature"]),
        .library(name: "PortfolioFeature", targets: ["PortfolioFeature"]),
        .library(name: "WidgetFeature", targets: ["WidgetFeature"]),
    ],
    targets: [
        // Looks up strings in the language chosen in Settings. Foundation only.
        .target(name: "Localization"),
        // Business rules: entities, repository contracts and use cases. Foundation only.
        .target(name: "Domain", dependencies: ["Localization"]),
        // Generic HTTP: knows nothing about crypto.
        .target(name: "Networking"),
        // CoinGecko, offline cache and SwiftData; implements the Domain repository contracts.
        .target(name: "DataLayer", dependencies: ["Domain", "Networking"]),
        // Colors, formatters and reusable SwiftUI components.
        .target(name: "DesignSystem", dependencies: ["Localization"]),
        .target(name: "MarketsFeature", dependencies: ["Domain", "DesignSystem", "Localization"]),
        .target(name: "CoinDetailFeature", dependencies: ["Domain", "DesignSystem", "Localization"]),
        .target(name: "PortfolioFeature", dependencies: ["Domain", "DesignSystem", "Localization"]),
        // Home Screen widget entries and views; the widget extension only wires it up.
        .target(name: "WidgetFeature", dependencies: ["Domain", "DesignSystem"]),

        // Fakes shared by the feature tests.
        .target(name: "TestSupport", dependencies: ["Domain"], path: "Tests/TestSupport"),

        .testTarget(name: "LocalizationTests", dependencies: ["Localization"]),
        .testTarget(name: "DomainTests", dependencies: ["Domain"]),
        .testTarget(name: "NetworkingTests", dependencies: ["Networking"]),
        .testTarget(name: "DesignSystemTests", dependencies: ["DesignSystem"]),
        .testTarget(name: "DataLayerTests", dependencies: ["DataLayer", "Domain", "Networking"]),
        .testTarget(name: "MarketsFeatureTests", dependencies: ["MarketsFeature", "TestSupport"]),
        .testTarget(name: "CoinDetailFeatureTests", dependencies: ["CoinDetailFeature", "TestSupport"]),
        .testTarget(name: "PortfolioFeatureTests", dependencies: ["PortfolioFeature", "TestSupport"]),
        .testTarget(name: "WidgetFeatureTests", dependencies: ["WidgetFeature", "TestSupport"]),
    ]
)
