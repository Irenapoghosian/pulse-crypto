import Domain
import Foundation

/// Downloads a coin logo. A protocol so tests don't touch the network.
public protocol ImageDataLoading: Sendable {
    func data(from url: URL) async -> Data?
}

public struct URLSessionImageLoader: ImageDataLoading {
    public init() {}

    public func data(from url: URL) async -> Data? {
        let request = URLRequest(url: url, timeoutInterval: 10)
        guard
            let (data, response) = try? await URLSession.shared.data(for: request),
            (response as? HTTPURLResponse)?.statusCode == 200
        else { return nil }
        return data
    }
}

/// Builds a widget entry for the coins the user picked.
///
/// Uses the same rules as the portfolio: the shared top-100 list is reused while
/// it's fresh, only coins outside it are fetched, and saved prices are shown
/// (marked as stale) when the network fails.
public struct MarketEntryLoader: Sendable {
    private let market: MarketRepository
    private let images: ImageDataLoading

    public init(market: MarketRepository, images: ImageDataLoading) {
        self.market = market
        self.images = images
    }

    public func entry(for requestedIDs: [String], now: Date = Date()) async -> MarketEntry {
        let ids = requestedIDs.removingDuplicates()
        guard !ids.isEmpty else { return MarketEntry(date: now, coins: [], isStale: false) }

        let snapshot = try? await market.topCoins(forceRefresh: false)
        let listIsLive = snapshot.map { !$0.isFromCache } ?? false
        var found: [String: Coin] = [:]
        for coin in snapshot?.coins ?? [] where ids.contains(coin.id) {
            found[coin.id] = coin
        }

        // A live list only lacks the missing coins; a saved list needs everything refreshed.
        let request = listIsLive ? ids.filter { found[$0] == nil } : ids
        var refreshed = false
        if !request.isEmpty, let fetched = try? await market.coins(ids: request) {
            refreshed = true
            for coin in fetched { found[coin.id] = coin }
        }

        let coins = ids.compactMap { found[$0] }
        let icons = await loadIcons(for: coins)
        return MarketEntry(
            date: now,
            coins: coins.map { WidgetCoin(coin: $0, iconData: icons[$0.id]) },
            isStale: !coins.isEmpty && !listIsLive && !refreshed
        )
    }

    private func loadIcons(for coins: [Coin]) async -> [String: Data] {
        await withTaskGroup(of: (String, Data?).self) { group in
            for coin in coins {
                guard let url = coin.imageURL else { continue }
                group.addTask { (coin.id, await images.data(from: url)) }
            }
            var icons: [String: Data] = [:]
            for await (id, data) in group {
                icons[id] = data
            }
            return icons
        }
    }
}

private extension Array where Element: Hashable {
    func removingDuplicates() -> [Element] {
        var seen = Set<Element>()
        return filter { seen.insert($0).inserted }
    }
}
