import Domain
import TestSupport
import XCTest
@testable import MarketsFeature

@MainActor
final class MarketsViewModelTests: XCTestCase {

    func testLoadShowsCoinsSortedByRank() async {
        let repository = FakeMarketRepository(coins: [Fixtures.solana, Fixtures.bitcoin, Fixtures.ethereum])
        let model = MarketsViewModel(repository: repository)

        await model.load()

        XCTAssertEqual(model.state, .loaded)
        XCTAssertEqual(model.visibleCoins.map(\.id), ["bitcoin", "ethereum", "solana"])
        XCTAssertEqual(repository.topCoinsCalls, [false])
    }

    func testRefreshForcesNetwork() async {
        let repository = FakeMarketRepository()
        let model = MarketsViewModel(repository: repository)

        await model.load()
        await model.refresh()

        XCTAssertEqual(repository.topCoinsCalls, [false, true])
    }

    func testFailureWithNothingOnScreenShowsMessage() async {
        let repository = FakeMarketRepository()
        repository.topCoinsResult = .failure(MarketDataError.offline)
        let model = MarketsViewModel(repository: repository)

        await model.load()

        guard case .failed(let message) = model.state else { return XCTFail("Expected failure") }
        XCTAssertTrue(message.contains("offline"))
    }

    func testFailedRefreshKeepsExistingCoins() async {
        let repository = FakeMarketRepository()
        let model = MarketsViewModel(repository: repository)
        await model.load()

        repository.topCoinsResult = .failure(MarketDataError.rateLimited)
        await model.refresh()

        XCTAssertEqual(model.state, .loaded)
        XCTAssertEqual(model.visibleCoins.count, Fixtures.coins.count)
    }

    func testCachedSnapshotIsFlagged() async {
        let model = MarketsViewModel(repository: FakeMarketRepository(isFromCache: true))
        await model.load()
        XCTAssertTrue(model.isShowingCachedData)
    }

    func testSortChangesOrder() async {
        let model = MarketsViewModel(repository: FakeMarketRepository())
        await model.load()

        model.sort = .gainers
        XCTAssertEqual(model.visibleCoins.first?.id, "solana")

        model.sort = .losers
        XCTAssertEqual(model.visibleCoins.first?.id, "ethereum")
    }

    func testQueryFiltersLocallyByRelevance() async {
        let model = MarketsViewModel(repository: FakeMarketRepository())
        await model.load()

        model.query = "eth"

        XCTAssertEqual(model.visibleCoins.map(\.id), ["ethereum", "ethena"])
    }

    func testRemoteSearchSkipsCoinsAlreadyListed() async {
        let repository = FakeMarketRepository()
        repository.searchResult = .success([
            CoinSearchResult(id: "ethereum", symbol: "ETH", name: "Ethereum"),
            CoinSearchResult(id: "ethereum-classic", symbol: "ETC", name: "Ethereum Classic"),
        ])
        let model = MarketsViewModel(repository: repository)
        await model.load()

        model.query = "ethereum"
        await model.search()

        XCTAssertEqual(model.searchResults.map(\.id), ["ethereum-classic"])
        XCTAssertFalse(model.isSearching)
    }

    func testClearingQueryClearsResultsWithoutNetwork() async {
        let repository = FakeMarketRepository()
        repository.searchResult = .success([CoinSearchResult(id: "x", symbol: "X", name: "X")])
        let model = MarketsViewModel(repository: repository)
        await model.load()

        model.query = "xx"
        await model.search()
        model.query = ""
        await model.search()

        XCTAssertTrue(model.searchResults.isEmpty)
        XCTAssertEqual(repository.searchQueries, ["xx"])
    }

    func testFailedSearchIsQuiet() async {
        let repository = FakeMarketRepository()
        repository.searchResult = .failure(MarketDataError.unavailable)
        let model = MarketsViewModel(repository: repository)
        await model.load()

        model.query = "doge"
        await model.search()

        XCTAssertEqual(model.state, .loaded)
        XCTAssertTrue(model.searchResults.isEmpty)
    }
}
