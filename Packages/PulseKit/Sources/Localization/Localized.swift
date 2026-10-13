import Foundation

/// Looks up Pulse's strings in the language chosen in Settings.
///
/// `String(localized:)` and the UIKit-backed parts of SwiftUI (navigation
/// titles, tab bars, toolbars, menus) always use the language the app was
/// launched in. To switch languages without a restart, every string built in
/// code goes through here and is read from the chosen `.lproj` directly.
public enum Localized {
    nonisolated(unsafe) private static var bundle: Bundle = .main
    nonisolated(unsafe) public private(set) static var locale: Locale = .current

    /// Reads strings from `languageCode` (e.g. "hy"). `nil`, or a language the
    /// app isn't translated into, goes back to the language it launched in.
    public static func use(languageCode: String?, in base: Bundle = .main, region: Locale.Region? = Locale.current.region) {
        guard
            let languageCode,
            let path = base.path(forResource: languageCode, ofType: "lproj"),
            let languageBundle = Bundle(path: path)
        else {
            bundle = base
            locale = .current
            return
        }
        bundle = languageBundle
        locale = Locale(languageCode: Locale.LanguageCode(languageCode), languageRegion: region)
    }

    /// The translation of `key`, with `arguments` filling its `%@` / `%lld` placeholders.
    /// Falls back to the key itself, which is the English text.
    public static func string(_ key: String, _ arguments: CVarArg...) -> String {
        let format = bundle.localizedString(forKey: key, value: key, table: nil)
        guard !arguments.isEmpty else { return format }
        return String(format: format, locale: locale, arguments: arguments)
    }
}
