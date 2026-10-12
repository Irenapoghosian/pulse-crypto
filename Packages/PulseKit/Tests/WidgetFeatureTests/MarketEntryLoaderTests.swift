import Domain
import TestSupport
import XCTest
@testable import WidgetFeature

final class MarketEntryLoaderTests: XCTestCase {

    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    func testUsesTheLiveListInTheChosenOrderWithoutExtraRequests() async {
        let market = FakeMarketRepository()
        let loader = MarketEntryLoader(market: market, images: FakeImageLoader())

        let entry = await loader.entry(for: ["solana", "bitcoin"], now: now)

        XCTAssertEqual(entry.coins.map(\.id), ["solana", "bitcoin"])
        XCTAssertEqual(entry.date, now)
        XCTAssertFalse(entry.isStale)
        XCTAssertTrue(market.coinsRequests.isEmpty)
    }

    func testFetchesOnlyCoinsOutsideTheList() async {
        let market = FakeMarketRepository(coins: [Fixtures.bitcoin])
        market.coinsResult = .success([Fixtures.ethena])
        let loader = MarketEntryLoader(market: market, images: FakeImageLoader())

        let entry = await loader.entry(for: ["bitcoin", "ethena"], now: now)

        XCTAssertEqual(market.coinsRequests, [["ethena"]])
        XCTAssertEqual(entry.coins.map(\.id), ["bitcoin", "ethena"])
        XCTAssertFalse(entry.isStale)
    }

    func testSavedListIsRefreshedAndMarkedStaleWhenThatFails() async {
        let market = FakeMarketRepository(isFromCache: true)
        market.coinsResult = .failure(MarketDataError.offline)
        let loader = MarketEntryLoader(market: market, images: FakeImageLoader())

        let entry = await loader.entry(for: ["bitcoin"], now: now)

        XCTAssertEqual(market.coinsRequests, [["bitcoin"]])
        XCTAssertEqual(entry.coins.map(\.id), ["bitcoin"])
        XCTAssertTrue(entry.isStale)
    }

    func testNothingAvailableGivesAnEmptyEntry() async {
        let market = FakeMarketRepository()
        market.topCoinsResult = .failure(MarketDataError.offline)
        market.coinsResult = .failure(MarketDataError.offline)
        let loader = MarketEntryLoader(market: market, images: FakeImageLoader())

        let entry = await loader.entry(for: ["bitcoin"], now: now)

        XCTAssertTrue(entry.coins.isEmpty)
        XCTAssertFalse(entry.isStale)
    }

    func testDuplicatesAreShownOnceAndLogosAreAttached() async throws {
        let logo = try XCTUnwrap(URL(string: "https://example.com/btc.png"))
        let bitcoin = Coin(id: "bitcoin", symbol: "BTC", name: "Bitcoin", imageURL: logo, price: 64_000)
        let market = FakeMarketRepository(coins: [bitcoin])
        let loader = MarketEntryLoader(market: market, images: FakeImageLoader([logo: Data([1, 2, 3])]))

        let entry = await loader.entry(for: ["bitcoin", "bitcoin"], now: now)

        XCTAssertEqual(entry.coins.count, 1)
        XCTAssertEqual(entry.coins.first?.iconData, Data([1, 2, 3]))
    }

    func testPlaceholderHasTheRequestedNumberOfCoins() {
        XCTAssertEqual(MarketEntry.placeholder(count: 1).coins.count, 1)
        XCTAssertEqual(MarketEntry.placeholder(count: 3).coins.map(\.id), ["bitcoin", "ethereum", "solana"])
    }
}

private struct FakeImageLoader: ImageDataLoading {
    var images: [URL: Data] = [:]

    init(_ images: [URL: Data] = [:]) {
        self.images = images
    }

    func data(from url: URL) async -> Data? {
        images[url]
    }
}
