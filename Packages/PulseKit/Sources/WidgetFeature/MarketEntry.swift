import Domain
import Foundation
import WidgetKit

/// One coin as a widget shows it. Widgets can't load images while they're on
/// screen, so the logo is downloaded together with the prices.
public struct WidgetCoin: Identifiable, Hashable, Sendable {
    public let coin: Coin
    public let iconData: Data?

    public var id: String { coin.id }

    public init(coin: Coin, iconData: Data? = nil) {
        self.coin = coin
        self.iconData = iconData
    }
}

/// What a widget shows at one point in time.
public struct MarketEntry: TimelineEntry, Sendable {
    public let date: Date
    /// In the order the user chose. Empty when no prices could be loaded.
    public let coins: [WidgetCoin]
    /// The prices come from the saved market list because the network failed.
    public let isStale: Bool

    public init(date: Date, coins: [WidgetCoin], isStale: Bool) {
        self.date = date
        self.coins = coins
        self.isStale = isStale
    }

    /// Sample data for the widget gallery and while the first timeline loads.
    public static func placeholder(count: Int, date: Date = Date()) -> MarketEntry {
        MarketEntry(
            date: date,
            coins: WidgetSamples.coins.prefix(count).map { WidgetCoin(coin: $0) },
            isStale: false
        )
    }
}

enum WidgetSamples {
    static let coins: [Coin] = [
        Coin(id: "bitcoin", symbol: "BTC", name: "Bitcoin", price: 82_906, priceChange24h: 1.42,
             sparkline7d: wave(base: 80_000, amplitude: 2_500, trend: 3_000)),
        Coin(id: "ethereum", symbol: "ETH", name: "Ethereum", price: 2_498.18, priceChange24h: -0.84,
             sparkline7d: wave(base: 2_560, amplitude: 60, trend: -70)),
        Coin(id: "solana", symbol: "SOL", name: "Solana", price: 109.27, priceChange24h: 3.15,
             sparkline7d: wave(base: 104, amplitude: 3, trend: 5)),
    ]

    /// A smooth, deterministic price line so previews look real but never change.
    private static func wave(base: Double, amplitude: Double, trend: Double) -> [Double] {
        (0..<48).map { step in
            let progress = Double(step) / 47
            return base + trend * progress + amplitude * sin(progress * .pi * 3)
        }
    }
}
