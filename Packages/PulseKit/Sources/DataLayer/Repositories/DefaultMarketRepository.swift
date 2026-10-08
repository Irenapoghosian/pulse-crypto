import Domain
import Foundation
import Networking

/// CoinGecko-backed `MarketRepository` with an offline cache.
///
/// CoinGecko refreshes free market data about once a minute and rate-limits
/// keyless clients hard, so a list fetched less than `freshness` seconds ago
/// is reused instead of asking again.
public struct DefaultMarketRepository: MarketRepository {
    private let api: CoinGeckoAPI
    private let cache: MarketCache
    private let freshness: TimeInterval
    private let now: @Sendable () -> Date

    /// - Parameter apiKey: optional CoinGecko Demo key; `nil` uses the keyless API.
    public init(apiKey: String?, http: HTTPClient = URLSessionHTTPClient()) {
        self.init(api: CoinGeckoAPI(apiKey: apiKey, http: http), cache: FileMarketCache())
    }

    init(
        api: CoinGeckoAPI,
        cache: MarketCache,
        freshness: TimeInterval = 60,
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.api = api
        self.cache = cache
        self.freshness = freshness
        self.now = now
    }

    public func topCoins(forceRefresh: Bool) async throws -> MarketSnapshot {
        let cached = await cache.load()

        if !forceRefresh, let cached, now().timeIntervalSince(cached.savedAt) < freshness {
            return Self.snapshot(from: cached, isFromCache: false)
        }

        do {
            let coins = try await api.markets()
            let fresh = CachedMarket(coins: coins, savedAt: now())
            await cache.save(fresh)
            return Self.snapshot(from: fresh, isFromCache: false)
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            // Better old prices than an empty screen.
            if let cached { return Self.snapshot(from: cached, isFromCache: true) }
            throw Self.translate(error)
        }
    }

    public func coins(ids: [String]) async throws -> [Coin] {
        guard !ids.isEmpty else { return [] }
        do {
            return try await api.markets(ids: ids, perPage: min(max(ids.count, 1), 250)).compactMap { $0.toDomain() }
        } catch {
            throw Self.translate(error)
        }
    }

    public func search(_ query: String) async throws -> [CoinSearchResult] {
        do {
            return try await api.search(query).coins.map { $0.toDomain() }
        } catch {
            throw Self.translate(error)
        }
    }

    public func priceHistory(for coinID: String, range: ChartRange) async throws -> [PricePoint] {
        do {
            return try await api.marketChart(id: coinID, days: range.days).toDomain()
        } catch {
            throw Self.translate(error)
        }
    }

    // MARK: Helpers

    private static func snapshot(from market: CachedMarket, isFromCache: Bool) -> MarketSnapshot {
        MarketSnapshot(
            coins: market.coins.compactMap { $0.toDomain() },
            updatedAt: market.savedAt,
            isFromCache: isFromCache
        )
    }

    /// Keeps HTTP details out of the features.
    static func translate(_ error: Error) -> Error {
        if error is CancellationError { return error }
        switch error as? NetworkError {
        case .offline?:
            return MarketDataError.offline
        case .rateLimited?:
            return MarketDataError.rateLimited
        default:
            return MarketDataError.unavailable
        }
    }
}
