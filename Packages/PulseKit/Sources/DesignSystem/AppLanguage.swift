import Foundation
import Localization

/// The language chosen in Settings, stored with `@AppStorage(AppLanguage.storageKey)`.
public enum AppLanguage: String, CaseIterable, Identifiable, Sendable {
    /// Follow the iPhone's language.
    case system
    case english
    case armenian
    case russian

    public static let storageKey = "language"

    public var id: String { rawValue }

    /// The localization folder name (`hy.lproj`), or `nil` for the system language.
    public var code: String? {
        switch self {
        case .system: nil
        case .english: "en"
        case .armenian: "hy"
        case .russian: "ru"
        }
    }

    /// Each language is written in itself, so people can always find their own.
    public var title: String {
        switch self {
        case .system: Localized.string("System")
        case .english: "English"
        case .armenian: "Հայերեն"
        case .russian: "Русский"
        }
    }
}
