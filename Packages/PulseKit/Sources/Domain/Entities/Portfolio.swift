import Foundation

/// How much of a coin the user owns. Keeps the coin's name and logo so the
/// portfolio can still be shown when prices can't be loaded.
public struct Holding: Identifiable, Hashable, Sendable {
    public var id: String { coin.id }
    public let coin: CoinIdentity
    public let amount: Double

    public init(coin: CoinIdentity, amount: Double) {
        self.coin = coin
        self.amount = amount
    }
}

/// A holding combined with its current market data.
public struct PortfolioPosition: Identifiable, Hashable, Sendable {
    public var id: String { holding.id }
    public let holding: Holding
    /// Nil when the price couldn't be loaded.
    public let coin: Coin?

    public init(holding: Holding, coin: Coin?) {
        self.holding = holding
        self.coin = coin
    }

    public var value: Double? {
        coin.map { $0.price * holding.amount }
    }

    /// Dollar change over 24h, derived from the percent change.
    public var change24hValue: Double? {
        guard let value, let percent = coin?.priceChange24h, percent > -100 else { return nil }
        return value - value / (1 + percent / 100)
    }
}

public struct AllocationSlice: Identifiable, Hashable, Sendable {
    public let id: String
    public let label: String
    public let value: Double
    /// 0...1
    public let share: Double

    public init(id: String, label: String, value: Double, share: Double) {
        self.id = id
        self.label = label
        self.value = value
        self.share = share
    }
}

public struct PortfolioSummary: Hashable, Sendable {
    /// Most valuable first; positions without a price come last.
    public let positions: [PortfolioPosition]
    public let totalValue: Double
    public let change24hValue: Double
    /// Percent, e.g. 2.5 for +2.5 %. Nil when nothing is priced.
    public let change24hPercent: Double?
    public let allocation: [AllocationSlice]
    /// True when at least one holding has no price.
    public let isIncomplete: Bool

    public static let empty = PortfolioSummary(
        positions: [], totalValue: 0, change24hValue: 0,
        change24hPercent: nil, allocation: [], isIncomplete: false
    )

    public init(
        positions: [PortfolioPosition],
        totalValue: Double,
        change24hValue: Double,
        change24hPercent: Double?,
        allocation: [AllocationSlice],
        isIncomplete: Bool
    ) {
        self.positions = positions
        self.totalValue = totalValue
        self.change24hValue = change24hValue
        self.change24hPercent = change24hPercent
        self.allocation = allocation
        self.isIncomplete = isIncomplete
    }
}
