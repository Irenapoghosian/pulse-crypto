import SwiftUI
import XCTest
@testable import DesignSystem

final class AppearanceTests: XCTestCase {

    func testSystemFollowsTheDevice() {
        XCTAssertNil(AppearancePreference.system.colorScheme)
        XCTAssertEqual(AppearancePreference.system.userInterfaceStyle, .unspecified)
    }

    func testExplicitChoices() {
        XCTAssertEqual(AppearancePreference.light.colorScheme, .light)
        XCTAssertEqual(AppearancePreference.dark.colorScheme, .dark)
        XCTAssertEqual(AppearancePreference.light.userInterfaceStyle, .light)
        XCTAssertEqual(AppearancePreference.dark.userInterfaceStyle, .dark)
    }

    func testStoredValuesStayStable() {
        // These strings are saved in UserDefaults; renaming a case must not lose the user's choice.
        XCTAssertEqual(AppearancePreference.allCases.map(\.rawValue), ["system", "light", "dark"])
        XCTAssertEqual(AppearancePreference(rawValue: "dark"), .dark)
    }
}
