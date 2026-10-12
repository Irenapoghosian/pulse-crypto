import XCTest
@testable import DesignSystem

final class FormatterTests: XCTestCase {
    private let us = Locale(identifier: "en_US")

    func testPriceUsesMoreDecimalsForCheaperCoins() {
        XCTAssertEqual(PulseFormat.price(64210.5, locale: us), "$64,210.50")
        XCTAssertEqual(PulseFormat.price(0.4821, locale: us), "$0.4821")
        XCTAssertEqual(PulseFormat.price(0.00001234, locale: us), "$0.00001234")
        XCTAssertEqual(PulseFormat.price(0, locale: us), "$0.00")
    }

    func testCompactCurrency() {
        XCTAssertEqual(PulseFormat.compactCurrency(1_270_000_000_000, locale: us), "$1.27T")
        XCTAssertEqual(PulseFormat.compactCurrency(845_200_000_000, locale: us), "$845.2B")
        XCTAssertEqual(PulseFormat.compactCurrency(12_400_000, locale: us), "$12.4M")
        XCTAssertEqual(PulseFormat.compactCurrency(950, locale: us), "$950.00")
    }

    func testPercentChangeAlwaysShowsASign() {
        XCTAssertEqual(PulseFormat.percentChange(2.45, locale: us), "+2.45%")
        XCTAssertEqual(PulseFormat.percentChange(-1.2, locale: us), "−1.20%")
        XCTAssertEqual(PulseFormat.percentChange(0, locale: us), "+0.00%")
    }
}

final class ShareFormatTests: XCTestCase {
    private let us = Locale(identifier: "en_US")

    func testShares() {
        XCTAssertEqual(PulseFormat.share(0.988, locale: us), "98.8%")
        XCTAssertEqual(PulseFormat.share(0.006, locale: us), "0.6%")
        XCTAssertEqual(PulseFormat.share(1, locale: us), "100%")
        XCTAssertEqual(PulseFormat.share(0, locale: us), "0%")
    }

    func testSliversAreNotShownAsZero() {
        XCTAssertEqual(PulseFormat.share(0.00002, locale: us), "<0.1%")
    }
}

final class AccessibilityTextTests: XCTestCase {
    private let us = Locale(identifier: "en_US")

    func testChange() {
        XCTAssertEqual(PulseAccessibility.change(2.45, locale: us), "up 2.45%")
        XCTAssertEqual(PulseAccessibility.change(-1.2, locale: us), "down 1.20%")
        XCTAssertEqual(PulseAccessibility.change(0, locale: us), "unchanged")
        XCTAssertNil(PulseAccessibility.change(nil, locale: us))
    }

    func testWeekTrend() {
        XCTAssertEqual(PulseAccessibility.weekTrend([1, 2, 3]), "7-day trend up")
        XCTAssertEqual(PulseAccessibility.weekTrend([3, 1]), "7-day trend down")
        XCTAssertEqual(PulseAccessibility.weekTrend([2, 5, 2]), "7-day trend flat")
        XCTAssertNil(PulseAccessibility.weekTrend([1]))
    }

    func testCoinSummaryReadsAsOneSentence() {
        let text = PulseAccessibility.coinSummary(
            name: "Bitcoin", symbol: "BTC", price: 83_532, change24h: 0.66,
            rank: 1, sparkline: [85_000, 83_532], locale: us
        )
        XCTAssertEqual(text, "Bitcoin, BTC, rank 1, $83,532.00, up 0.66% today, 7-day trend down")
    }

    func testCoinSummaryWithoutPrice() {
        let text = PulseAccessibility.coinSummary(name: "Ethena", symbol: "ENA", price: nil, change24h: nil, locale: us)
        XCTAssertEqual(text, "Ethena, ENA, price unavailable")
    }
}
