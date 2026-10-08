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
