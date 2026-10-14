import Foundation
import Localization

/// Consistent number formatting across the app, in the language chosen in Settings.
/// Pure functions, so they're unit-testable.
public enum PulseFormat {

    /// `$64,210.55`, `$0.4821`, `$0.00001234` — more decimals for cheaper coins.
    public static func price(_ value: Double, locale: Locale = Localized.locale) -> String {
        let fractionDigits: Int
        switch abs(value) {
        case 1...: fractionDigits = 2
        case 0.01..<1: fractionDigits = 4
        case 0: fractionDigits = 2
        default: fractionDigits = 8
        }
        return value.formatted(
            .currency(code: "USD")
                .locale(locale)
                .precision(.fractionLength(fractionDigits))
        )
    }

    /// `$1.27T`, `$845.2B`, `$12.4M` — for market cap and volume. The language
    /// decides the words and where the symbol goes ("1,68 трлн $" in Russian).
    public static func compactCurrency(_ value: Double, locale: Locale = Localized.locale) -> String {
        guard abs(value) >= 1_000 else { return price(value, locale: locale) }
        // Compact currency formatting needs iOS 18, so build it from a compact
        // number and the language's own currency pattern ("$1" or "1 $").
        let number = abs(value).formatted(
            .number.locale(locale).notation(.compactName).precision(.fractionLength(0...2))
        )
        let pattern = 1.0.formatted(.currency(code: "USD").locale(locale).precision(.fractionLength(0)))
        let sign = value < 0 ? "-" : ""
        guard let one = pattern.range(of: "1") else { return sign + "$" + number }
        let prefix = String(pattern[..<one.lowerBound])
        let suffix = String(pattern[one.upperBound...])
        return sign + prefix + number + suffix
    }

    /// `19.7M` — for supply.
    public static func compactNumber(_ value: Double, locale: Locale = Localized.locale) -> String {
        value.formatted(.number.locale(locale).notation(.compactName).precision(.fractionLength(0...2)))
    }

    /// `+2.45%` / `−1.20%` from a percent value like `2.45`.
    public static func percentChange(_ value: Double, locale: Locale = Localized.locale) -> String {
        let magnitude = (abs(value) / 100).formatted(
            .percent.locale(locale).precision(.fractionLength(2))
        )
        return (value >= 0 ? "+" : "−") + magnitude
    }

    /// Portfolio shares: `98.8%`, `0.6%`, and `<0.1%` for slivers that would otherwise read as `0%`.
    public static func share(_ fraction: Double, locale: Locale = Localized.locale) -> String {
        let style = FloatingPointFormatStyle<Double>.Percent(locale: locale).precision(.fractionLength(0...1))
        if fraction > 0, fraction < 0.001 {
            return "<" + 0.001.formatted(style)
        }
        return fraction.formatted(style)
    }

    /// Coin amounts: up to 8 decimals, no trailing zeros.
    public static func amount(_ value: Double, locale: Locale = Localized.locale) -> String {
        value.formatted(.number.locale(locale).precision(.fractionLength(0...8)))
    }
}
