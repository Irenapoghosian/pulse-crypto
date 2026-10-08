import Domain
import TestSupport
import XCTest
@testable import CoinDetailFeature

@MainActor
final class CoinDetailViewModelTests: XCTestCase {

    func testLoadsWeekChartByDefault() async {
        let repository = FakeMarketRepository()
        repository.historyResults[.week] = .success(Fixtures.history(prices: [100, 90, 120]))
        let model = makeModel(repository: repository, coin: Fixtures.bitcoin)

        await model.load()

        XCTAssertEqual(model.range, .week)
        XCTAssertEqual(model.points.map(\.price), [100, 90, 120])
        XCTAssertEqual(model.displayedChange ?? 0, 20, accuracy: 0.0001)
        XCTAssertEqual(model.displayedPrice, Fixtures.bitcoin.price) // live price, not last chart point
        XCTAssertTrue(repository.coinsRequests.isEmpty) // already had the coin
    }

    func testFetchesCoinWhenOpenedFromSearch() async {
        let repository = FakeMarketRepository()
        repository.coinsResult = .success([Fixtures.solana])
        let model = makeModel(repository: repository, coin: nil, identity: Fixtures.solana.identity)

        await model.load()

        XCTAssertEqual(model.coin, Fixtures.solana)
        XCTAssertEqual(repository.coinsRequests, [["solana"]])
    }

    func testChangingRangeLoadsAndCaches() async {
        let repository = FakeMarketRepository()
        repository.historyResults[.year] = .success(Fixtures.history(prices: [50, 100]))
        let model = makeModel(repository: repository, coin: Fixtures.bitcoin)
        await model.load()

        await model.select(.year)
        XCTAssertEqual(model.displayedChange ?? 0, 100, accuracy: 0.0001)

        await model.select(.week)
        await model.select(.year)

        // Week and year were each fetched once; switching back used the cache.
        XCTAssertEqual(repository.historyRequests, [.week, .year])
    }

    func testScrubbingShowsSelectedPointAndChangeToIt() async {
        let repository = FakeMarketRepository()
        let points = Fixtures.history(prices: [100, 150, 120])
        repository.historyResults[.week] = .success(points)
        let model = makeModel(repository: repository, coin: Fixtures.bitcoin)
        await model.load()

        model.selectedDate = points[1].date.addingTimeInterval(60) // near the middle point

        XCTAssertEqual(model.selectedPoint, points[1])
        XCTAssertEqual(model.displayedPrice, 150)
        XCTAssertEqual(model.displayedChange ?? 0, 50, accuracy: 0.0001)
    }

    func testChartErrorIsExplained() async {
        let repository = FakeMarketRepository()
        repository.historyResults[.week] = .failure(MarketDataError.rateLimited)
        let model = makeModel(repository: repository, coin: Fixtures.bitcoin)

        await model.load()

        guard case .failed(let message) = model.chart else { return XCTFail("Expected failure") }
        XCTAssertTrue(message.contains("Too many requests"))
    }

    func testEmptyHistoryIsAFailureState() async {
        let repository = FakeMarketRepository()
        repository.historyResults[.week] = .success([])
        let model = makeModel(repository: repository, coin: Fixtures.bitcoin)

        await model.load()

        XCTAssertEqual(model.chart, .failed("No price history for this period."))
    }

    private func makeModel(
        repository: FakeMarketRepository,
        coin: Coin?,
        identity: CoinIdentity = Fixtures.bitcoin.identity
    ) -> CoinDetailViewModel {
        CoinDetailViewModel(identity: identity, coin: coin, repository: repository)
    }
}
