import Foundation

/// Consistent number formatting across the app. Pure functions, so they're unit-testable.
public enum PulseFormat {

    /// `$64,210.55`, `$0.4821`, `$0.00001234` — more decimals for cheaper coins.
    public static func price(_ value: Double, locale: Locale = .current) -> String {
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

    /// `$1.27T`, `$845.2B`, `$12.4M` — for market cap and volume.
    public static func compactCurrency(_ value: Double, locale: Locale = .current) -> String {
        let units: [(threshold: Double, suffix: String)] = [(1e12, "T"), (1e9, "B"), (1e6, "M"), (1e3, "K")]
        guard let unit = units.first(where: { abs(value) >= $0.threshold }) else {
            return price(value, locale: locale)
        }
        let scaled = (value / unit.threshold).formatted(
            .currency(code: "USD").locale(locale).precision(.fractionLength(0...2))
        )
        return scaled + unit.suffix
    }

    /// `19.7M` — for supply.
    public static func compactNumber(_ value: Double, locale: Locale = .current) -> String {
        value.formatted(.number.locale(locale).notation(.compactName).precision(.fractionLength(0...2)))
    }

    /// `+2.45%` / `−1.20%` from a percent value like `2.45`.
    public static func percentChange(_ value: Double, locale: Locale = .current) -> String {
        let magnitude = (abs(value) / 100).formatted(
            .percent.locale(locale).precision(.fractionLength(2))
        )
        return (value >= 0 ? "+" : "−") + magnitude
    }

    /// Portfolio shares: `98.8%`, `0.6%`, and `<0.1%` for slivers that would otherwise read as `0%`.
    public static func share(_ fraction: Double, locale: Locale = .current) -> String {
        let style = FloatingPointFormatStyle<Double>.Percent(locale: locale).precision(.fractionLength(0...1))
        if fraction > 0, fraction < 0.001 {
            return "<" + 0.001.formatted(style)
        }
        return fraction.formatted(style)
    }

    /// Coin amounts: up to 8 decimals, no trailing zeros.
    public static func amount(_ value: Double, locale: Locale = .current) -> String {
        value.formatted(.number.locale(locale).precision(.fractionLength(0...8)))
    }
}
