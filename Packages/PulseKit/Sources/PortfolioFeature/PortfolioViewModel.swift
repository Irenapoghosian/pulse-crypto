import Domain
import Foundation
import Observation

@MainActor
@Observable
public final class PortfolioViewModel {

    public enum State: Equatable {
        case loading
        case loaded
        case failed(String)
    }

    public enum PriceStatus: Equatable {
        case live
        /// The network failed; values use the last saved market prices.
        case saved
        /// No prices at all; only amounts can be shown.
        case unavailable
    }

    // MARK: State

    public private(set) var state: State = .loading
    public private(set) var summary: PortfolioSummary = .empty
    public private(set) var priceStatus: PriceStatus = .live
    /// Drives the add / edit sheet.
    public var editor: HoldingEditorViewModel?

    public var isEmpty: Bool { summary.positions.isEmpty }

    // MARK: Dependencies

    private let holdings: HoldingsRepository
    private let market: MarketRepository

    public init(holdings: HoldingsRepository, market: MarketRepository) {
        self.holdings = holdings
        self.market = market
    }

    // MARK: Intents

    public func load() async {
        if summary.positions.isEmpty, state != .loaded { state = .loading }
        do {
            let items = try await holdings.all()
            let coins = await prices(for: items)
            summary = PortfolioCalculator.summary(holdings: items, coins: coins)
            state = .loaded
        } catch is CancellationError {
            return
        } catch {
            state = .failed("Your portfolio couldn't be opened. Please try again.")
        }
    }

    public func delete(_ holding: Holding) async {
        try? await holdings.delete(coinID: holding.id)
        await load()
    }

    public func startAdding() {
        editor = makeEditor(holding: nil)
    }

    public func startEditing(_ holding: Holding) {
        editor = makeEditor(holding: holding)
    }

    /// The holding for a coin, if the user owns it. Used by "Add to portfolio" elsewhere.
    public func holding(for coinID: String) -> Holding? {
        summary.positions.first { $0.id == coinID }?.holding
    }

    /// An editor for any screen (e.g. coin detail): edits the existing holding
    /// for that coin, or adds a new one with the coin already chosen.
    public func makeEditor(for coin: CoinIdentity) -> HoldingEditorViewModel {
        if let existing = holding(for: coin.id) {
            return makeEditor(holding: existing)
        }
        return HoldingEditorViewModel(
            preselected: coin,
            holdings: holdings,
            market: market,
            onSaved: { [weak self] in await self?.load() }
        )
    }

    // MARK: Private

    private func makeEditor(holding: Holding?) -> HoldingEditorViewModel {
        HoldingEditorViewModel(
            editing: holding,
            holdings: holdings,
            market: market,
            onSaved: { [weak self] in await self?.load() }
        )
    }

    private func prices(for items: [Holding]) async -> [Coin] {
        guard !items.isEmpty else {
            priceStatus = .live
            return []
        }
        do {
            let coins = try await market.coins(ids: items.map(\.id))
            priceStatus = .live
            return coins
        } catch {
            // Fall back to the saved market list (covers the top 100 coins).
            if let snapshot = try? await market.topCoins(forceRefresh: false), !snapshot.coins.isEmpty {
                priceStatus = .saved
                return snapshot.coins
            }
            priceStatus = .unavailable
            return []
        }
    }
}
