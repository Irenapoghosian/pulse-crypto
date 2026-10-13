import Foundation
import Localization

/// Turns holdings + prices into everything the portfolio screen shows. Pure and synchronous.
public enum PortfolioCalculator {

    /// - Parameter maxSlices: allocation keeps the biggest coins and groups the rest as "Other".
    public static func summary(holdings: [Holding], coins: [Coin], maxSlices: Int = 5) -> PortfolioSummary {
        let coinsByID = Dictionary(coins.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let positions = holdings
            .map { PortfolioPosition(holding: $0, coin: coinsByID[$0.id]) }
            .sorted { lhs, rhs in
                switch (lhs.value, rhs.value) {
                case let (leftValue?, rightValue?): return leftValue > rightValue
                case (.some, nil): return true
                case (nil, .some): return false
                case (nil, nil): return lhs.holding.coin.name < rhs.holding.coin.name
                }
            }

        let priced = positions.compactMap { position in position.value.map { (position, $0) } }
        let total = priced.reduce(0) { $0 + $1.1 }
        let change = positions.compactMap(\.change24hValue).reduce(0, +)
        let previous = total - change
        let percent: Double? = previous > 0 ? change / previous * 100 : nil

        return PortfolioSummary(
            positions: positions,
            totalValue: total,
            change24hValue: change,
            change24hPercent: priced.isEmpty ? nil : percent,
            allocation: allocation(priced, total: total, maxSlices: maxSlices),
            isIncomplete: priced.count < positions.count
        )
    }

    private static func allocation(
        _ priced: [(PortfolioPosition, Double)],
        total: Double,
        maxSlices: Int
    ) -> [AllocationSlice] {
        guard total > 0 else { return [] }
        let nonZero = priced.filter { $0.1 > 0 }
        let top = nonZero.prefix(maxSlices).map { position, value in
            AllocationSlice(
                id: position.id,
                label: position.holding.coin.symbol,
                value: value,
                share: value / total
            )
        }
        let rest = nonZero.dropFirst(maxSlices).reduce(0) { $0 + $1.1 }
        guard rest > 0 else { return top }
        return top + [AllocationSlice(id: "other", label: Localized.string("Other"), value: rest, share: rest / total)]
    }
}

/// Reads amounts typed by people in any locale: "0,5" in Armenian or Russian, "1,250.75" in English.
public enum AmountParser {

    /// Returns a positive amount, or nil for empty, invalid, zero or negative input.
    public static func parse(_ text: String, locale: Locale = .current) -> Double? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let decimal = locale.decimalSeparator ?? "."
        let grouping = locale.groupingSeparator ?? ","

        // Drop grouping separators (including the non-breaking spaces many locales use),
        // then normalise the decimal separator to ".".
        var normalized = trimmed
            .replacingOccurrences(of: "\u{00A0}", with: "")
            .replacingOccurrences(of: "\u{202F}", with: "")
            .replacingOccurrences(of: " ", with: "")
        if grouping != decimal, !grouping.trimmingCharacters(in: .whitespaces).isEmpty {
            normalized = normalized.replacingOccurrences(of: grouping, with: "")
        }
        normalized = normalized.replacingOccurrences(of: decimal, with: ".")
        // People often type "." on a keyboard that expects ",", and vice versa.
        if decimal != "," { normalized = normalized.replacingOccurrences(of: ",", with: "") }
        normalized = normalized.replacingOccurrences(of: ",", with: ".")

        guard
            normalized.filter({ $0 == "." }).count <= 1,
            normalized.allSatisfy({ $0.isNumber || $0 == "." }),
            let value = Double(normalized),
            value > 0,
            value.isFinite
        else { return nil }
        return value
    }
}
