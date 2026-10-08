import XCTest
@testable import Domain

final class MarketRulesTests: XCTestCase {

    private let btc = Coin(id: "bitcoin", symbol: "BTC", name: "Bitcoin", price: 64_000, priceChange24h: 1.5, marketCapRank: 1, totalVolume: 30)
    private let eth = Coin(id: "ethereum", symbol: "ETH", name: "Ethereum", price: 3_100, priceChange24h: -2.0, marketCapRank: 2, totalVolume: 15)
    private let ena = Coin(id: "ethena", symbol: "ENA", name: "Ethena", price: 0.6, priceChange24h: 0.4, marketCapRank: 60, totalVolume: 9)
    private let weth = Coin(id: "weth", symbol: "WETH", name: "Wrapped Ether", price: 3_100, priceChange24h: nil, marketCapRank: nil, totalVolume: 40)

    private var all: [Coin] { [btc, eth, ena, weth] }

    // MARK: Filter

    func testEmptyQueryReturnsEverything() {
        XCTAssertEqual(MarketRules.filter(all, query: "  "), all)
    }

    func testFilterMatchesNameAndSymbolCaseInsensitively() {
        XCTAssertEqual(MarketRules.filter(all, query: "bit").map(\.id), ["bitcoin"])
        XCTAssertEqual(MarketRules.filter(all, query: "Btc").map(\.id), ["bitcoin"])
    }

    func testExactSymbolRanksFirstThenPrefixThenContains() {
        // "eth": ETH is exact, Ethena and Ethereum prefix by name, WETH only contains it.
        let ids = MarketRules.filter(all, query: "eth").map(\.id)
        XCTAssertEqual(ids.first, "ethereum")
        XCTAssertEqual(ids.last, "weth")
        XCTAssertEqual(Set(ids), ["ethereum", "ethena", "weth"])
    }

    // MARK: Sort

    func testSortByRankPutsUnrankedLast() {
        XCTAssertEqual(MarketRules.sort(all, by: .rank).map(\.id), ["bitcoin", "ethereum", "ethena", "weth"])
    }

    func testGainersAndLosers() {
        XCTAssertEqual(MarketRules.sort(all, by: .gainers).first?.id, "bitcoin")
        XCTAssertEqual(MarketRules.sort(all, by: .losers).first?.id, "ethereum")
        // Coins without change data never top either list.
        XCTAssertEqual(MarketRules.sort(all, by: .gainers).last?.id, "weth")
        XCTAssertEqual(MarketRules.sort(all, by: .losers).last?.id, "weth")
    }

    func testSortByVolume() {
        XCTAssertEqual(MarketRules.sort(all, by: .volume).map(\.id), ["weth", "bitcoin", "ethereum", "ethena"])
    }

    // MARK: Change

    func testChangeOverPoints() {
        let points = [
            PricePoint(date: .distantPast, price: 100),
            PricePoint(date: .now, price: 125),
        ]
        XCTAssertEqual(MarketRules.change(over: points) ?? 0, 25, accuracy: 0.0001)
    }

    func testChangeNeedsTwoUsablePoints() {
        XCTAssertNil(MarketRules.change(over: []))
        XCTAssertNil(MarketRules.change(over: [PricePoint(date: .now, price: 0), PricePoint(date: .now, price: 5)]))
    }

    func testChartRangeDays() {
        XCTAssertEqual(ChartRange.allCases.map(\.days), [1, 7, 30, 365])
    }
}

final class SearchCoinsUseCaseTests: XCTestCase {

    func testShortQueriesDoNotHitTheNetwork() async throws {
        let repository = RecordingRepository()
        let search = SearchCoinsUseCase(repository: repository)

        let results = try await search("b", excluding: [])

        XCTAssertTrue(results.isEmpty)
        XCTAssertTrue(repository.queries.isEmpty)
    }

    func testCoinsAlreadyShownAreExcluded() async throws {
        let repository = RecordingRepository()
        repository.results = [
            CoinSearchResult(id: "bitcoin", symbol: "BTC", name: "Bitcoin"),
            CoinSearchResult(id: "bitcoin-cash", symbol: "BCH", name: "Bitcoin Cash"),
        ]
        let search = SearchCoinsUseCase(repository: repository)

        let results = try await search("  bitcoin ", excluding: ["bitcoin"])

        XCTAssertEqual(results.map(\.id), ["bitcoin-cash"])
        XCTAssertEqual(repository.queries, ["bitcoin"]) // trimmed
    }
}

private final class RecordingRepository: MarketRepository, @unchecked Sendable {
    var results: [CoinSearchResult] = []
    private(set) var queries: [String] = []

    func topCoins(forceRefresh: Bool) async throws -> MarketSnapshot {
        MarketSnapshot(coins: [], updatedAt: .now, isFromCache: false)
    }
    func coins(ids: [String]) async throws -> [Coin] { [] }
    func search(_ query: String) async throws -> [CoinSearchResult] {
        queries.append(query)
        return results
    }
    func priceHistory(for coinID: String, range: ChartRange) async throws -> [PricePoint] { [] }
}
