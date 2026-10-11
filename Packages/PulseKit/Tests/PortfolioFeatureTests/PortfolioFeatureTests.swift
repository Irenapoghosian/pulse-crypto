import Domain
import TestSupport
import XCTest
@testable import PortfolioFeature

@MainActor
final class PortfolioViewModelTests: XCTestCase {

    func testEmptyPortfolio() async {
        let model = PortfolioViewModel(holdings: FakeHoldingsRepository(), market: FakeMarketRepository())

        await model.load()

        XCTAssertEqual(model.state, .loaded)
        XCTAssertTrue(model.isEmpty)
    }

    func testLiveMarketListPricesHoldingsWithoutExtraRequest() async {
        let holdings = FakeHoldingsRepository([Fixtures.holding(Fixtures.bitcoin, 0.5), Fixtures.holding(Fixtures.ethereum, 2)])
        let market = FakeMarketRepository()
        let model = PortfolioViewModel(holdings: holdings, market: market)

        await model.load()

        XCTAssertEqual(model.priceStatus, .live)
        XCTAssertEqual(model.summary.totalValue, 0.5 * 64_000 + 2 * 3_100, accuracy: 0.001)
        XCTAssertTrue(market.coinsRequests.isEmpty)
    }

    func testOnlyCoinsOutsideTheMarketListAreFetched() async {
        let holdings = FakeHoldingsRepository([Fixtures.holding(Fixtures.bitcoin, 1), Fixtures.holding(Fixtures.ethena, 100)])
        let market = FakeMarketRepository(coins: [Fixtures.bitcoin, Fixtures.ethereum])
        market.coinsResult = .success([Fixtures.ethena])
        let model = PortfolioViewModel(holdings: holdings, market: market)

        await model.load()

        XCTAssertEqual(market.coinsRequests, [["ethena"]])
        XCTAssertEqual(model.priceStatus, .live)
        XCTAssertEqual(model.summary.totalValue, 64_000 + 60, accuracy: 0.001)
    }

    func testSavedMarketListIsRefreshedForHeldCoins() async {
        let holdings = FakeHoldingsRepository([Fixtures.holding(Fixtures.bitcoin, 1)])
        let market = FakeMarketRepository(isFromCache: true)
        market.coinsResult = .success([Fixtures.bitcoin])
        let model = PortfolioViewModel(holdings: holdings, market: market)

        await model.load()

        XCTAssertEqual(market.coinsRequests, [["bitcoin"]])
        XCTAssertEqual(model.priceStatus, .live)
    }

    func testFailedExtraRequestKeepsLiveListPrices() async {
        let holdings = FakeHoldingsRepository([Fixtures.holding(Fixtures.bitcoin, 1), Fixtures.holding(Fixtures.ethena, 100)])
        let market = FakeMarketRepository(coins: [Fixtures.bitcoin])
        market.coinsResult = .failure(MarketDataError.rateLimited)
        let model = PortfolioViewModel(holdings: holdings, market: market)

        await model.load()

        XCTAssertEqual(model.priceStatus, .live)
        XCTAssertTrue(model.summary.isIncomplete)
        XCTAssertEqual(model.summary.totalValue, 64_000, accuracy: 0.001)
    }

    func testFallsBackToSavedPricesWhenOffline() async {
        let holdings = FakeHoldingsRepository([Fixtures.holding(Fixtures.solana, 10)])
        let market = FakeMarketRepository(isFromCache: true)
        market.coinsResult = .failure(MarketDataError.offline)
        let model = PortfolioViewModel(holdings: holdings, market: market)

        await model.load()

        XCTAssertEqual(model.priceStatus, .saved)
        XCTAssertEqual(model.summary.totalValue, 1_500, accuracy: 0.001)
    }

    func testShowsAmountsWhenNoPricesAtAll() async {
        let holdings = FakeHoldingsRepository([Fixtures.holding(Fixtures.solana, 10)])
        let market = FakeMarketRepository()
        market.coinsResult = .failure(MarketDataError.offline)
        market.topCoinsResult = .failure(MarketDataError.offline)
        let model = PortfolioViewModel(holdings: holdings, market: market)

        await model.load()

        XCTAssertEqual(model.state, .loaded)
        XCTAssertEqual(model.priceStatus, .unavailable)
        XCTAssertEqual(model.summary.positions.count, 1)
        XCTAssertNil(model.summary.positions.first?.value)
    }

    func testStorageFailureShowsError() async {
        let holdings = FakeHoldingsRepository()
        holdings.failure = MarketDataError.unavailable
        let model = PortfolioViewModel(holdings: holdings, market: FakeMarketRepository())

        await model.load()

        guard case .failed = model.state else { return XCTFail("Expected failure") }
    }

    func testDeleteRemovesAndReloads() async {
        let btc = Fixtures.holding(Fixtures.bitcoin, 1)
        let holdings = FakeHoldingsRepository([btc, Fixtures.holding(Fixtures.ethereum, 1)])
        let market = FakeMarketRepository()
        market.coinsResult = .success(Fixtures.coins)
        let model = PortfolioViewModel(holdings: holdings, market: market)
        await model.load()

        await model.delete(btc)

        XCTAssertEqual(model.summary.positions.map(\.id), ["ethereum"])
    }

    func testEditorForOwnedCoinEditsExistingAmount() async {
        let holdings = FakeHoldingsRepository([Fixtures.holding(Fixtures.bitcoin, 0.5)])
        let market = FakeMarketRepository()
        market.coinsResult = .success([Fixtures.bitcoin])
        let model = PortfolioViewModel(holdings: holdings, market: market)
        await model.load()

        let owned = model.makeEditor(for: Fixtures.bitcoin.identity)
        let notOwned = model.makeEditor(for: Fixtures.solana.identity)

        XCTAssertEqual(owned.mode, .edit)
        XCTAssertEqual(owned.amount, 0.5)
        XCTAssertEqual(notOwned.mode, .add)
        XCTAssertEqual(notOwned.selectedCoin, Fixtures.solana.identity)
        XCTAssertFalse(notOwned.canSave) // no amount yet
    }
}

@MainActor
final class HoldingEditorViewModelTests: XCTestCase {
    private let english = Locale(identifier: "en_US")

    func testAddFlowSavesAndNotifies() async {
        let holdings = FakeHoldingsRepository()
        var savedCount = 0
        let editor = HoldingEditorViewModel(
            editing: nil, holdings: holdings, market: FakeMarketRepository(), locale: english,
            onSaved: { savedCount += 1 }
        )
        await editor.loadSuggestions()

        XCTAssertEqual(editor.suggestions.first?.id, "bitcoin")
        XCTAssertFalse(editor.canSave)

        editor.select(Fixtures.bitcoin.identity)
        editor.amountText = "0.25"
        XCTAssertTrue(editor.canSave)
        XCTAssertEqual(editor.estimatedValue ?? 0, 16_000, accuracy: 0.001)

        let saved = await editor.save()

        XCTAssertTrue(saved)
        XCTAssertEqual(holdings.stored, [Fixtures.holding(Fixtures.bitcoin, 0.25)])
        XCTAssertEqual(savedCount, 1)
    }

    func testInvalidAmountCannotBeSaved() async {
        let editor = HoldingEditorViewModel(
            preselected: Fixtures.bitcoin.identity, holdings: FakeHoldingsRepository(),
            market: FakeMarketRepository(), locale: english
        )
        for text in ["", "abc", "0", "-1"] {
            editor.amountText = text
            XCTAssertFalse(editor.canSave, "\"\(text)\" should not be savable")
        }
        let saved = await editor.save()
        XCTAssertFalse(saved)
    }

    func testEditModeIsLockedToItsCoinAndPrefillsAmount() {
        let editor = HoldingEditorViewModel(
            editing: Fixtures.holding(Fixtures.ethereum, 1.5), holdings: FakeHoldingsRepository(),
            market: FakeMarketRepository(), locale: english
        )

        XCTAssertEqual(editor.mode, .edit)
        XCTAssertEqual(editor.amountText, "1.5")
        XCTAssertFalse(editor.canChangeCoin)

        editor.clearSelection()
        XCTAssertEqual(editor.selectedCoin, Fixtures.ethereum.identity)
    }

    func testSearchCombinesLocalAndRemoteResults() async {
        let market = FakeMarketRepository()
        market.searchResult = .success([
            CoinSearchResult(id: "ethereum", symbol: "ETH", name: "Ethereum"),
            CoinSearchResult(id: "ethereum-classic", symbol: "ETC", name: "Ethereum Classic"),
        ])
        let editor = HoldingEditorViewModel(editing: nil, holdings: FakeHoldingsRepository(), market: market, locale: english)
        await editor.loadSuggestions()

        editor.query = "ethereum"
        await editor.search()

        XCTAssertEqual(editor.suggestions.map(\.id), ["ethereum", "ethereum-classic"])
    }

    func testSaveFailureShowsMessage() async {
        let holdings = FakeHoldingsRepository()
        holdings.failure = MarketDataError.unavailable
        let editor = HoldingEditorViewModel(
            preselected: Fixtures.bitcoin.identity, holdings: holdings,
            market: FakeMarketRepository(), locale: english
        )
        editor.amountText = "1"

        let saved = await editor.save()

        XCTAssertFalse(saved)
        XCTAssertNotNil(editor.errorMessage)
    }
}
