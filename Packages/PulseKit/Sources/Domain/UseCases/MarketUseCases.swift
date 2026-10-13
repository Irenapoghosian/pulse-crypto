import Foundation
import Localization

/// How the market list can be ordered.
public enum MarketSort: String, CaseIterable, Identifiable, Sendable {
    case rank, gainers, losers, volume

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .rank: Localized.string("Market cap")
        case .gainers: Localized.string("Top gainers")
        case .losers: Localized.string("Top losers")
        case .volume: Localized.string("Volume")
        }
    }
}

/// Pure list rules: filtering and sorting. No I/O, so they are trivially testable.
public enum MarketRules {

    /// Case-insensitive match on name or symbol. Symbol prefix matches rank first
    /// so typing "eth" puts Ethereum before coins that merely contain "eth".
    public static func filter(_ coins: [Coin], query: String) -> [Coin] {
        let needle = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !needle.isEmpty else { return coins }

        let matches = coins.filter {
            $0.name.lowercased().contains(needle) || $0.symbol.lowercased().contains(needle)
        }
        let exactSymbol = matches.filter { $0.symbol.lowercased() == needle }
        let prefix = matches.filter {
            $0.symbol.lowercased() != needle
                && ($0.symbol.lowercased().hasPrefix(needle) || $0.name.lowercased().hasPrefix(needle))
        }
        let rest = matches.filter { coin in
            !exactSymbol.contains(coin) && !prefix.contains(coin)
        }
        return exactSymbol + prefix + rest
    }

    public static func sort(_ coins: [Coin], by sort: MarketSort) -> [Coin] {
        switch sort {
        case .rank:
            return coins.sorted { ($0.marketCapRank ?? .max) < ($1.marketCapRank ?? .max) }
        case .gainers:
            return coins.sorted { ($0.priceChange24h ?? -.infinity) > ($1.priceChange24h ?? -.infinity) }
        case .losers:
            return coins.sorted { ($0.priceChange24h ?? .infinity) < ($1.priceChange24h ?? .infinity) }
        case .volume:
            return coins.sorted { ($0.totalVolume ?? 0) > ($1.totalVolume ?? 0) }
        }
    }

    /// Percent change between the first and last point of a chart, e.g. 12.5 for +12.5 %.
    public static func change(over points: [PricePoint]) -> Double? {
        guard let first = points.first?.price, let last = points.last?.price, first != 0 else { return nil }
        return (last - first) / first * 100
    }
}

/// Searches remotely and leaves out coins the user can already see in the list.
public struct SearchCoinsUseCase: Sendable {
    private let repository: MarketRepository

    public init(repository: MarketRepository) {
        self.repository = repository
    }

    public func callAsFunction(_ query: String, excluding shownIDs: Set<String>) async throws -> [CoinSearchResult] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 2 else { return [] }
        return try await repository.search(trimmed).filter { !shownIDs.contains($0.id) }
    }
}
