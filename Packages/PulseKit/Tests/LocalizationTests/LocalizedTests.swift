import XCTest
@testable import Localization

final class LocalizedTests: XCTestCase {

    override func setUp() {
        super.setUp()
        Localized.use(languageCode: nil)
    }

    func testMissingKeysFallBackToTheEnglishKey() {
        XCTAssertEqual(Localized.string("Markets"), "Markets")
    }

    func testPlaceholdersAreFilledInOrder() {
        XCTAssertEqual(Localized.string("From %@ to %@", "$1", "$2"), "From $1 to $2")
        XCTAssertEqual(Localized.string("rank %lld", 7), "rank 7")
    }

    func testUnknownLanguageFallsBackToTheLaunchLanguage() {
        Localized.use(languageCode: "xx")

        XCTAssertEqual(Localized.string("Markets"), "Markets")
    }
}
