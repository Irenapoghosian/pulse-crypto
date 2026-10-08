import Foundation

/// A coin with its current market data. Prices are in US dollars.
public struct Coin: Identifiable, Hashable, Sendable {
    public let id: String
    public let symbol: String
    public let name: String
    public let imageURL: URL?
    public let price: Double
    /// Percent change over the last 24 hours, e.g. `-2.5` for −2.5 %.
    public let priceChange24h: Double?
    public let marketCap: Double?
    public let marketCapRank: Int?
    public let totalVolume: Double?
    public let high24h: Double?
    public let low24h: Double?
    public let allTimeHigh: Double?
    public let circulatingSupply: Double?
    /// Hourly prices for the last 7 days, oldest first.
    public let sparkline7d: [Double]

    public init(
        id: String,
        symbol: String,
        name: String,
        imageURL: URL? = nil,
        price: Double,
        priceChange24h: Double? = nil,
        marketCap: Double? = nil,
        marketCapRank: Int? = nil,
        totalVolume: Double? = nil,
        high24h: Double? = nil,
        low24h: Double? = nil,
        allTimeHigh: Double? = nil,
        circulatingSupply: Double? = nil,
        sparkline7d: [Double] = []
    ) {
        self.id = id
        self.symbol = symbol
        self.name = name
        self.imageURL = imageURL
        self.price = price
        self.priceChange24h = priceChange24h
        self.marketCap = marketCap
        self.marketCapRank = marketCapRank
        self.totalVolume = totalVolume
        self.high24h = high24h
        self.low24h = low24h
        self.allTimeHigh = allTimeHigh
        self.circulatingSupply = circulatingSupply
        self.sparkline7d = sparkline7d
    }

    /// Lightweight identity used for navigation between features.
    public var identity: CoinIdentity {
        CoinIdentity(id: id, symbol: symbol, name: name, imageURL: imageURL)
    }
}

/// Just enough to show a coin and load the rest. Search results and coins both produce one,
/// so any screen can open the coin detail without depending on another feature.
public struct CoinIdentity: Identifiable, Hashable, Sendable {
    public let id: String
    public let symbol: String
    public let name: String
    public let imageURL: URL?

    public init(id: String, symbol: String, name: String, imageURL: URL? = nil) {
        self.id = id
        self.symbol = symbol
        self.name = name
        self.imageURL = imageURL
    }
}
