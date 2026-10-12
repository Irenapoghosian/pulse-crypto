import Foundation

/// Settings read from Info.plist. Compiled into both the app and the widget
/// extension, which each carry the same `CoinGeckoAPIKey` entry.
enum AppConfig {
    /// Optional CoinGecko Demo key from `Config/Secrets.xcconfig` (never committed).
    static var coinGeckoAPIKey: String? {
        guard
            let key = Bundle.main.object(forInfoDictionaryKey: "CoinGeckoAPIKey") as? String,
            !key.isEmpty,
            !key.hasPrefix("$(")
        else { return nil }
        return key
    }
}
