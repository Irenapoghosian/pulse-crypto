import Foundation

/// Where market data comes from. Implemented in `DataLayer`; faked in tests.
public protocol MarketRepository: Sendable {
    /// Top coins by market cap. Uses recent saved data unless `forceRefresh` is true,
    /// and falls back to saved data when the network fails.
    func topCoins(forceRefresh: Bool) async throws -> MarketSnapshot

    /// Current market data for specific coins.
    func coins(ids: [String]) async throws -> [Coin]

    func search(_ query: String) async throws -> [CoinSearchResult]

    func priceHistory(for coinID: String, range: ChartRange) async throws -> [PricePoint]
}
