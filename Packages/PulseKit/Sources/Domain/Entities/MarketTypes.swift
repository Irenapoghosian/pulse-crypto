import Foundation

/// The coin list plus where it came from, so the UI can say "showing saved data".
public struct MarketSnapshot: Sendable, Equatable {
    public let coins: [Coin]
    public let updatedAt: Date
    /// True when the network failed and these are the last saved prices.
    public let isFromCache: Bool

    public init(coins: [Coin], updatedAt: Date, isFromCache: Bool) {
        self.coins = coins
        self.updatedAt = updatedAt
        self.isFromCache = isFromCache
    }
}

/// A coin returned by search. It has no price; the detail screen loads that.
public struct CoinSearchResult: Identifiable, Hashable, Sendable {
    public let id: String
    public let symbol: String
    public let name: String
    public let thumbURL: URL?
    public let marketCapRank: Int?

    public init(id: String, symbol: String, name: String, thumbURL: URL? = nil, marketCapRank: Int? = nil) {
        self.id = id
        self.symbol = symbol
        self.name = name
        self.thumbURL = thumbURL
        self.marketCapRank = marketCapRank
    }

    public var identity: CoinIdentity {
        CoinIdentity(id: id, symbol: symbol, name: name, imageURL: thumbURL)
    }
}

public struct PricePoint: Hashable, Sendable {
    public let date: Date
    public let price: Double

    public init(date: Date, price: Double) {
        self.date = date
        self.price = price
    }
}

public enum ChartRange: String, CaseIterable, Identifiable, Sendable {
    case day, week, month, year

    public var id: String { rawValue }

    /// Number of days of history to request.
    public var days: Int {
        switch self {
        case .day: 1
        case .week: 7
        case .month: 30
        case .year: 365
        }
    }

    public var title: String {
        switch self {
        case .day: "1D"
        case .week: "1W"
        case .month: "1M"
        case .year: "1Y"
        }
    }
}

/// Errors the UI can explain to people. The data layer translates
/// transport errors into these, so features never see HTTP details.
public enum MarketDataError: Error, Equatable, Sendable {
    case offline
    case rateLimited
    case unavailable
}
