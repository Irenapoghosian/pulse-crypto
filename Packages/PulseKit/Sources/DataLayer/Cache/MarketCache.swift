import Foundation

/// The last successful market response and when it was fetched.
struct CachedMarket: Codable, Equatable, Sendable {
    let coins: [CoinMarketDTO]
    let savedAt: Date
}

/// Persists the latest market list so the app still shows prices offline.
protocol MarketCache: Sendable {
    func load() async -> CachedMarket?
    func save(_ market: CachedMarket) async
}

/// Stores the list as JSON in the Caches directory (the system may purge it; that's fine).
actor FileMarketCache: MarketCache {
    private let fileURL: URL
    private var memory: CachedMarket?

    init(fileURL: URL = FileMarketCache.defaultURL) {
        self.fileURL = fileURL
    }

    static var defaultURL: URL {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("markets-v2.json")
    }

    func load() -> CachedMarket? {
        if let memory { return memory }
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        memory = try? JSONDecoder().decode(CachedMarket.self, from: data)
        return memory
    }

    func save(_ market: CachedMarket) {
        memory = market
        guard let data = try? JSONEncoder().encode(market) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}

/// For tests and previews.
actor InMemoryMarketCache: MarketCache {
    private var stored: CachedMarket?

    init(_ stored: CachedMarket? = nil) {
        self.stored = stored
    }

    func load() -> CachedMarket? { stored }
    func save(_ market: CachedMarket) { stored = market }
}
