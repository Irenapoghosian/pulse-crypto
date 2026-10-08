// swift-tools-version: 5.10
import PackageDescription

/// Pulse is split into small modules with one-way dependencies:
///
///   Features ──▶ Domain ◀── DataLayer ──▶ Networking
///      │
///      └──────▶ DesignSystem
///
/// Features never import DataLayer or each other; the app target wires everything together.
let package = Package(
    name: "PulseKit",
    platforms: [.iOS(.v17)],
    products: [
        .library(name: "Domain", targets: ["Domain"]),
        .library(name: "Networking", targets: ["Networking"]),
        .library(name: "DataLayer", targets: ["DataLayer"]),
        .library(name: "DesignSystem", targets: ["DesignSystem"]),
        .library(name: "MarketsFeature", targets: ["MarketsFeature"]),
        .library(name: "CoinDetailFeature", targets: ["CoinDetailFeature"]),
    ],
    targets: [
        // Business rules: entities, repository contracts and use cases. Foundation only.
        .target(name: "Domain"),
        // Generic HTTP: knows nothing about crypto.
        .target(name: "Networking"),
        // CoinGecko + caching; implements the Domain repository contracts.
        .target(name: "DataLayer", dependencies: ["Domain", "Networking"]),
        // Colors, formatters and reusable SwiftUI components.
        .target(name: "DesignSystem"),
        .target(name: "MarketsFeature", dependencies: ["Domain", "DesignSystem"]),
        .target(name: "CoinDetailFeature", dependencies: ["Domain", "DesignSystem"]),

        // Fakes shared by the feature tests.
        .target(name: "TestSupport", dependencies: ["Domain"], path: "Tests/TestSupport"),

        .testTarget(name: "DomainTests", dependencies: ["Domain"]),
        .testTarget(name: "NetworkingTests", dependencies: ["Networking"]),
        .testTarget(name: "DesignSystemTests", dependencies: ["DesignSystem"]),
        .testTarget(name: "DataLayerTests", dependencies: ["DataLayer", "Domain", "Networking"]),
        .testTarget(name: "MarketsFeatureTests", dependencies: ["MarketsFeature", "TestSupport"]),
        .testTarget(name: "CoinDetailFeatureTests", dependencies: ["CoinDetailFeature", "TestSupport"]),
    ]
)
