import Domain
import Foundation
import Localization
import Observation

/// Adds a coin to the portfolio or changes the amount of an existing holding.
@MainActor
@Observable
public final class HoldingEditorViewModel: Identifiable {

    public enum Mode: Equatable {
        case add
        case edit
    }

    public let id = UUID()
    public let mode: Mode

    // MARK: State

    public private(set) var selectedCoin: CoinIdentity?
    public var amountText: String
    public var query = ""
    public private(set) var suggestions: [CoinIdentity] = []
    public private(set) var isSaving = false
    public private(set) var errorMessage: String?

    public var amount: Double? { AmountParser.parse(amountText, locale: locale) }
    public var canSave: Bool { selectedCoin != nil && amount != nil && !isSaving }
    /// Add mode lets people pick another coin; edit mode is locked to its coin.
    public var canChangeCoin: Bool { mode == .add }

    /// Rough value of the entered amount, when the price is known.
    public var estimatedValue: Double? {
        guard let amount, let id = selectedCoin?.id, let price = prices[id] else { return nil }
        return amount * price
    }

    // MARK: Dependencies

    private let holdings: HoldingsRepository
    private let market: MarketRepository
    private let searchCoins: SearchCoinsUseCase
    private let locale: Locale
    private let onSaved: @MainActor () async -> Void
    private var topCoins: [Coin] = []
    private var prices: [String: Double] = [:]

    /// Edit an existing holding, or start empty when `holding` is nil.
    public init(
        editing holding: Holding?,
        holdings: HoldingsRepository,
        market: MarketRepository,
        locale: Locale = .current,
        onSaved: @escaping @MainActor () async -> Void = {}
    ) {
        self.mode = holding == nil ? .add : .edit
        self.selectedCoin = holding?.coin
        self.amountText = holding.map { Self.format($0.amount, locale: locale) } ?? ""
        self.holdings = holdings
        self.market = market
        self.searchCoins = SearchCoinsUseCase(repository: market)
        self.locale = locale
        self.onSaved = onSaved
    }

    /// Add a holding with the coin already chosen (from the coin detail screen).
    public convenience init(
        preselected coin: CoinIdentity,
        holdings: HoldingsRepository,
        market: MarketRepository,
        locale: Locale = .current,
        onSaved: @escaping @MainActor () async -> Void = {}
    ) {
        self.init(editing: nil, holdings: holdings, market: market, locale: locale, onSaved: onSaved)
        selectedCoin = coin
    }

    // MARK: Intents

    /// Loads the top coins for the picker and for value estimates.
    public func loadSuggestions() async {
        if let snapshot = try? await market.topCoins(forceRefresh: false) {
            topCoins = snapshot.coins
            prices = Dictionary(snapshot.coins.map { ($0.id, $0.price) }, uniquingKeysWith: { first, _ in first })
        }
        suggestions = defaultSuggestions
    }

    /// Called (debounced) as the query changes.
    public func search() async {
        let current = query.trimmingCharacters(in: .whitespaces)
        guard !current.isEmpty else {
            suggestions = defaultSuggestions
            return
        }
        let local = MarketRules.filter(topCoins, query: current).prefix(20).map(\.identity)
        suggestions = Array(local)

        let remote = (try? await searchCoins(current, excluding: Set(local.map(\.id)))) ?? []
        guard current == query.trimmingCharacters(in: .whitespaces) else { return }
        suggestions = Array(local) + remote.prefix(20).map(\.identity)
    }

    public func select(_ coin: CoinIdentity) {
        selectedCoin = coin
        query = ""
    }

    public func clearSelection() {
        guard canChangeCoin else { return }
        selectedCoin = nil
        suggestions = defaultSuggestions
    }

    /// Returns true when saved, so the view can dismiss itself.
    @discardableResult
    public func save() async -> Bool {
        guard let coin = selectedCoin, let amount, !isSaving else { return false }
        isSaving = true
        defer { isSaving = false }
        do {
            try await holdings.save(Holding(coin: coin, amount: amount))
            errorMessage = nil
            await onSaved()
            return true
        } catch {
            errorMessage = Localized.string("Couldn't save. Please try again.")
            return false
        }
    }

    // MARK: Private

    private var defaultSuggestions: [CoinIdentity] {
        topCoins.prefix(30).map(\.identity)
    }

    static func format(_ amount: Double, locale: Locale) -> String {
        amount.formatted(.number.locale(locale).grouping(.never).precision(.fractionLength(0...8)))
    }
}
