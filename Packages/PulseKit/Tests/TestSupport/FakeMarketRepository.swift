import Domain
import Foundation

/// A scriptable `MarketRepository` for feature tests.
public final class FakeMarketRepository: MarketRepository, @unchecked Sendable {
    public var topCoinsResult: Result<MarketSnapshot, Error>
    public var coinsResult: Result<[Coin], Error> = .success([])
    public var searchResult: Result<[CoinSearchResult], Error> = .success([])
    public var historyResults: [ChartRange: Result<[PricePoint], Error>] = [:]

    public private(set) var topCoinsCalls: [Bool] = []
    public private(set) var searchQueries: [String] = []
    public private(set) var historyRequests: [ChartRange] = []
    public private(set) var coinsRequests: [[String]] = []

    public init(coins: [Coin] = Fixtures.coins, isFromCache: Bool = false) {
        topCoinsResult = .success(MarketSnapshot(coins: coins, updatedAt: Fixtures.date, isFromCache: isFromCache))
    }

    public func topCoins(forceRefresh: Bool) async throws -> MarketSnapshot {
        topCoinsCalls.append(forceRefresh)
        return try topCoinsResult.get()
    }

    public func coins(ids: [String]) async throws -> [Coin] {
        coinsRequests.append(ids)
        return try coinsResult.get()
    }

    public func search(_ query: String) async throws -> [CoinSearchResult] {
        searchQueries.append(query)
        return try searchResult.get()
    }

    public func priceHistory(for coinID: String, range: ChartRange) async throws -> [PricePoint] {
        historyRequests.append(range)
        return try (historyResults[range] ?? .success(Fixtures.history(prices: [100, 110]))).get()
    }
}

public enum Fixtures {
    public static let date = Date(timeIntervalSince1970: 1_760_000_000)

    public static let bitcoin = Coin(
        id: "bitcoin", symbol: "BTC", name: "Bitcoin", price: 64_000,
        priceChange24h: 1.5, marketCap: 1.2e12, marketCapRank: 1, totalVolume: 30e9
    )
    public static let ethereum = Coin(
        id: "ethereum", symbol: "ETH", name: "Ethereum", price: 3_100,
        priceChange24h: -2.0, marketCap: 3.7e11, marketCapRank: 2, totalVolume: 15e9
    )
    public static let solana = Coin(
        id: "solana", symbol: "SOL", name: "Solana", price: 150,
        priceChange24h: 6.2, marketCap: 7e10, marketCapRank: 5, totalVolume: 4e9
    )
    public static let ethena = Coin(
        id: "ethena", symbol: "ENA", name: "Ethena", price: 0.6,
        priceChange24h: 0.4, marketCap: 1e9, marketCapRank: 60, totalVolume: 9e8
    )

    public static let coins = [bitcoin, ethereum, solana, ethena]

    public static func history(prices: [Double]) -> [PricePoint] {
        prices.enumerated().map { index, price in
            PricePoint(date: date.addingTimeInterval(Double(index) * 3600), price: price)
        }
    }
}
