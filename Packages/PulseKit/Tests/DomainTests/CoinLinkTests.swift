import XCTest
@testable import Domain

final class CoinLinkTests: XCTestCase {

    func testRoundTrip() {
        let coin = CoinIdentity(
            id: "usd-coin", symbol: "USDC", name: "USD Coin",
            imageURL: URL(string: "https://example.com/usdc.png?size=large")
        )

        let url = CoinLink.url(for: coin)

        XCTAssertEqual(url.scheme, "pulse")
        XCTAssertEqual(CoinLink.identity(from: url), coin)
    }

    func testNamesWithSpacesAndSymbolsSurvive() {
        let coin = CoinIdentity(id: "wrapped-bitcoin", symbol: "WBTC", name: "Wrapped Bitcoin & Co")
        XCTAssertEqual(CoinLink.identity(from: CoinLink.url(for: coin)), coin)
    }

    func testMissingDetailsFallBackToTheID() throws {
        let url = try XCTUnwrap(URL(string: "pulse://coin/solana"))

        let identity = try XCTUnwrap(CoinLink.identity(from: url))

        XCTAssertEqual(identity.id, "solana")
        XCTAssertEqual(identity.symbol, "SOLANA")
        XCTAssertEqual(identity.name, "Solana")
        XCTAssertNil(identity.imageURL)
    }

    func testRejectsOtherLinks() {
        let links = ["https://coin/bitcoin", "pulse://portfolio/bitcoin", "pulse://coin", "pulse://coin/", "pulse://coin/a/b"]
        for link in links {
            XCTAssertNil(URL(string: link).flatMap(CoinLink.identity(from:)), "\(link) should be rejected")
        }
    }
}
