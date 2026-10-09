import XCTest
@testable import Domain

final class PortfolioCalculatorTests: XCTestCase {

    private let btc = Coin(id: "bitcoin", symbol: "BTC", name: "Bitcoin", price: 50_000, priceChange24h: 10)
    private let eth = Coin(id: "ethereum", symbol: "ETH", name: "Ethereum", price: 2_000, priceChange24h: -20)
    private let sol = Coin(id: "solana", symbol: "SOL", name: "Solana", price: 100, priceChange24h: nil)

    private func holding(_ coin: Coin, _ amount: Double) -> Holding {
        Holding(coin: coin.identity, amount: amount)
    }

    func testEmptyPortfolio() {
        let summary = PortfolioCalculator.summary(holdings: [], coins: [btc])
        XCTAssertEqual(summary.totalValue, 0)
        XCTAssertNil(summary.change24hPercent)
        XCTAssertTrue(summary.allocation.isEmpty)
        XCTAssertFalse(summary.isIncomplete)
    }

    func testTotalsAndOrdering() {
        // BTC 0.1 → $5,000; ETH 1 → $2,000; SOL 10 → $1,000
        let summary = PortfolioCalculator.summary(
            holdings: [holding(sol, 10), holding(btc, 0.1), holding(eth, 1)],
            coins: [btc, eth, sol]
        )

        XCTAssertEqual(summary.totalValue, 8_000, accuracy: 0.001)
        XCTAssertEqual(summary.positions.map(\.id), ["bitcoin", "ethereum", "solana"])
    }

    func testDailyChangeIsWeightedByValue() {
        // BTC: $5,000 now after +10% → was $4,545.45 (+$454.55)
        // ETH: $2,000 now after −20% → was $2,500 (−$500)
        let summary = PortfolioCalculator.summary(
            holdings: [holding(btc, 0.1), holding(eth, 1)],
            coins: [btc, eth]
        )

        XCTAssertEqual(summary.change24hValue, 454.545 - 500, accuracy: 0.01)
        let previous = 4_545.4545 + 2_500
        XCTAssertEqual(summary.change24hPercent ?? 0, (7_000 - previous) / previous * 100, accuracy: 0.001)
    }

    func testMissingPriceMarksSummaryIncompleteAndSortsLast() {
        let summary = PortfolioCalculator.summary(
            holdings: [holding(sol, 10), holding(btc, 0.1)],
            coins: [btc] // no SOL price
        )

        XCTAssertTrue(summary.isIncomplete)
        XCTAssertEqual(summary.totalValue, 5_000, accuracy: 0.001)
        XCTAssertEqual(summary.positions.last?.id, "solana")
        XCTAssertNil(summary.positions.last?.value)
    }

    func testAllocationGroupsSmallHoldingsIntoOther() {
        let coins = (1...7).map { Coin(id: "c\($0)", symbol: "C\($0)", name: "Coin \($0)", price: Double($0)) }
        let holdings = coins.map { holding($0, 1) }

        let slices = PortfolioCalculator.summary(holdings: holdings, coins: coins, maxSlices: 5).allocation

        XCTAssertEqual(slices.map(\.label), ["C7", "C6", "C5", "C4", "C3", "Other"])
        XCTAssertEqual(slices.last?.value, 3) // C2 + C1
        XCTAssertEqual(slices.map(\.share).reduce(0, +), 1, accuracy: 0.0001)
    }
}

final class AmountParserTests: XCTestCase {
    private let armenian = Locale(identifier: "hy_AM")
    private let english = Locale(identifier: "en_US")
    private let german = Locale(identifier: "de_DE")

    func testCommaDecimalLocales() {
        XCTAssertEqual(AmountParser.parse("0,5", locale: armenian), 0.5)
        XCTAssertEqual(AmountParser.parse("1 250,75", locale: armenian), 1250.75)
        XCTAssertEqual(AmountParser.parse("1.250,75", locale: german), 1250.75)
    }

    func testDotIsAcceptedEvenWhenLocaleUsesComma() {
        XCTAssertEqual(AmountParser.parse("0.25", locale: armenian), 0.25)
    }

    func testEnglishGrouping() {
        XCTAssertEqual(AmountParser.parse("1,250.75", locale: english), 1250.75)
        XCTAssertEqual(AmountParser.parse(" 2 ", locale: english), 2)
    }

    func testRejectsInvalidInput() {
        for text in ["", "   ", "abc", "1.2.3", "0", "-5", "1e5"] {
            XCTAssertNil(AmountParser.parse(text, locale: english), "\"\(text)\" should be rejected")
        }
    }
}
