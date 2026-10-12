import SwiftUI
import UIKit

/// The user's Light / Dark choice, stored with `@AppStorage(AppearancePreference.storageKey)`.
public enum AppearancePreference: String, CaseIterable, Identifiable, Sendable {
    /// Follow the iPhone's own Light or Dark setting.
    case system
    case light
    case dark

    public static let storageKey = "appearance"

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .system: "System"
        case .light: "Light"
        case .dark: "Dark"
        }
    }

    public var systemImage: String {
        switch self {
        case .system: "circle.lefthalf.filled"
        case .light: "sun.max"
        case .dark: "moon"
        }
    }

    /// For SwiftUI previews and `preferredColorScheme`; `nil` means "follow the system".
    public var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }

    /// Applied to the app's windows, so sheets, menus and alerts switch too.
    public var userInterfaceStyle: UIUserInterfaceStyle {
        switch self {
        case .system: .unspecified
        case .light: .light
        case .dark: .dark
        }
    }
}
