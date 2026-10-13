import DesignSystem
import Foundation
import Localization
import Observation

/// Switches Pulse's language from Settings without restarting the app.
///
/// Strings built in code come from `Localized`, which reads the chosen
/// `.lproj`. `PulseApp` puts `locale` in the environment for SwiftUI text and
/// rebuilds the screens when `revision` changes, so navigation titles, tab
/// bars and menus (drawn by UIKit) pick up the new language too. The choice is
/// also saved as `AppleLanguages`, so the next launch and system UI agree.
@MainActor
@Observable
final class LanguageSwitcher {
    private(set) var locale: Locale
    /// Changes on every switch; used as the root view's identity.
    private(set) var revision = 0

    init() {
        let saved = UserDefaults.standard.string(forKey: AppLanguage.storageKey)
            .flatMap(AppLanguage.init(rawValue:)) ?? .system
        // At launch "System" means whatever iOS picked, including a language set for Pulse in the Settings app.
        Localized.use(languageCode: saved.code ?? Bundle.main.preferredLocalizations.first)
        locale = Localized.locale
    }

    func select(_ language: AppLanguage) {
        if let code = language.code {
            UserDefaults.standard.set([code], forKey: "AppleLanguages")
            Localized.use(languageCode: code)
        } else {
            UserDefaults.standard.removeObject(forKey: "AppleLanguages")
            Localized.use(languageCode: Self.deviceLanguageCode)
        }
        locale = Localized.locale
        revision += 1
    }

    /// The iPhone's own language, among the ones Pulse is translated into.
    private static var deviceLanguageCode: String {
        let device = UserDefaults(suiteName: UserDefaults.globalDomain)?.stringArray(forKey: "AppleLanguages")
            ?? Locale.preferredLanguages
        return Bundle.preferredLocalizations(from: Bundle.main.localizations, forPreferences: device).first ?? "en"
    }
}
