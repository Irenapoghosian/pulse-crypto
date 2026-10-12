import DataLayer
import Domain
import SwiftUI
import UIKit
import WidgetFeature
import WidgetKit

@main
struct PulseWidgetBundle: WidgetBundle {
    var body: some Widget {
        CoinWidget()
        WatchlistWidget()
    }
}

/// The extension's composition root, like `AppContainer` in the app. The widget
/// reuses the app's modules, so it shares the same API client, cache and rules.
enum WidgetDependencies {
    static let market: MarketRepository = DefaultMarketRepository(apiKey: AppConfig.coinGeckoAPIKey)
    static let loader = MarketEntryLoader(market: market, images: URLSessionImageLoader())
    /// CoinGecko's free data updates about once a minute; half an hour keeps
    /// the widget useful without spending the API limit.
    static let refreshInterval: TimeInterval = 30 * 60

    static func timeline(for ids: [String]) async -> Timeline<MarketEntry> {
        let entry = await loader.entry(for: ids)
        return Timeline(entries: [entry], policy: .after(entry.date.addingTimeInterval(refreshInterval)))
    }
}

// MARK: - Small: one coin

struct CoinWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: "CoinWidget", intent: SelectCoinIntent.self, provider: CoinProvider()) { entry in
            CoinWidgetView(entry: entry)
                .containerBackground(for: .widget) { Color(uiColor: .systemBackground) }
        }
        .configurationDisplayName("Coin")
        .description("Price, 24h change and the last 7 days of one coin.")
        .supportedFamilies([.systemSmall])
    }
}

struct CoinProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> MarketEntry {
        .placeholder(count: 1)
    }

    func snapshot(for configuration: SelectCoinIntent, in context: Context) async -> MarketEntry {
        if context.isPreview { return .placeholder(count: 1) }
        return await WidgetDependencies.loader.entry(for: [configuration.coinID])
    }

    func timeline(for configuration: SelectCoinIntent, in context: Context) async -> Timeline<MarketEntry> {
        await WidgetDependencies.timeline(for: [configuration.coinID])
    }
}

// MARK: - Medium: watchlist

struct WatchlistWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: "WatchlistWidget", intent: SelectWatchlistIntent.self, provider: WatchlistProvider()) { entry in
            WatchlistWidgetView(entry: entry)
                .containerBackground(for: .widget) { Color(uiColor: .systemBackground) }
        }
        .configurationDisplayName("Watchlist")
        .description("Three coins at a glance. Tap one to open it in Pulse.")
        .supportedFamilies([.systemMedium])
    }
}

struct WatchlistProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> MarketEntry {
        .placeholder(count: 3)
    }

    func snapshot(for configuration: SelectWatchlistIntent, in context: Context) async -> MarketEntry {
        if context.isPreview { return .placeholder(count: 3) }
        return await WidgetDependencies.loader.entry(for: configuration.coinIDs)
    }

    func timeline(for configuration: SelectWatchlistIntent, in context: Context) async -> Timeline<MarketEntry> {
        await WidgetDependencies.timeline(for: configuration.coinIDs)
    }
}

// MARK: - Previews

#Preview("Coin", as: .systemSmall) {
    CoinWidget()
} timeline: {
    MarketEntry.placeholder(count: 1)
}

#Preview("Watchlist", as: .systemMedium) {
    WatchlistWidget()
} timeline: {
    MarketEntry.placeholder(count: 3)
}
