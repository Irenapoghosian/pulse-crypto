import Foundation
import Localization

/// VoiceOver phrases shared by every screen and the widgets, so a coin always
/// sounds the same wherever it appears. Pure functions, so they're unit-testable.
public enum PulseAccessibility {

    /// "up 2.45%", "down 1.20%" or "unchanged".
    public static func change(_ percent: Double?, locale: Locale = .current) -> String? {
        guard let percent else { return nil }
        guard percent != 0 else { return Localized.string("unchanged") }
        let magnitude = (abs(percent) / 100).formatted(.percent.locale(locale).precision(.fractionLength(2)))
        return percent > 0 ? Localized.string("up %@", magnitude) : Localized.string("down %@", magnitude)
    }

    /// "7-day trend up" from a sparkline, or `nil` when there isn't one.
    public static func weekTrend(_ values: [Double]) -> String? {
        guard values.count > 1, let first = values.first, let last = values.last else { return nil }
        if last > first { return Localized.string("7-day trend up") }
        if last < first { return Localized.string("7-day trend down") }
        return Localized.string("7-day trend flat")
    }

    /// One sentence for a coin row: "Bitcoin, BTC, rank 1, $83,532.00, up 0.66% today, 7-day trend down".
    public static func coinSummary(
        name: String,
        symbol: String,
        price: Double?,
        change24h: Double?,
        rank: Int? = nil,
        sparkline: [Double] = [],
        locale: Locale = .current
    ) -> String {
        var parts = [name, symbol]
        if let rank { parts.append(Localized.string("rank %lld", rank)) }
        parts.append(price.map { PulseFormat.price($0, locale: locale) } ?? Localized.string("price unavailable"))
        if let change = change(change24h, locale: locale) { parts.append(Localized.string("%@ today", change)) }
        if let trend = weekTrend(sparkline) { parts.append(trend) }
        return parts.joined(separator: ", ")
    }
}
