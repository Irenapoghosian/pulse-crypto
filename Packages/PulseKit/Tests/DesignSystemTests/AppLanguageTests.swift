import XCTest
@testable import DesignSystem

final class AppLanguageTests: XCTestCase {

    func testCodesMatchTheLocalizationFolders() {
        XCTAssertNil(AppLanguage.system.code)
        XCTAssertEqual(AppLanguage.english.code, "en")
        XCTAssertEqual(AppLanguage.armenian.code, "hy")
        XCTAssertEqual(AppLanguage.russian.code, "ru")
    }

    func testLanguagesAreNamedInThemselves() {
        XCTAssertEqual(AppLanguage.english.title, "English")
        XCTAssertEqual(AppLanguage.armenian.title, "Հայերեն")
        XCTAssertEqual(AppLanguage.russian.title, "Русский")
    }

    func testStoredValuesStayStable() {
        // Saved in UserDefaults; renaming a case must not lose the user's choice.
        XCTAssertEqual(AppLanguage.allCases.map(\.rawValue), ["system", "english", "armenian", "russian"])
    }
}
