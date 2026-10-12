import AppIntents
import Domain

/// A coin the user can pick when editing a widget.
struct CoinEntity: AppEntity {
    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Coin"
    static var defaultQuery = CoinQuery()

    let id: String
    let symbol: String
    let name: String

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)", subtitle: "\(symbol)")
    }

    init(id: String, symbol: String, name: String) {
        self.id = id
        self.symbol = symbol
        self.name = name
    }

    init(coin: Coin) {
        self.init(id: coin.id, symbol: coin.symbol, name: coin.name)
    }

    init(result: CoinSearchResult) {
        self.init(id: result.id, symbol: result.symbol, name: result.name)
    }
}

/// Suggests the top 100 coins and searches CoinGecko for anything else,
/// through the same repository the app uses.
struct CoinQuery: EntityStringQuery {
    func entities(for identifiers: [CoinEntity.ID]) async throws -> [CoinEntity] {
        let known = (try? await WidgetDependencies.market.topCoins(forceRefresh: false).coins) ?? []
        return identifiers.map { id in
            if let coin = known.first(where: { $0.id == id }) {
                return CoinEntity(coin: coin)
            }
            return CoinEntity(id: id, symbol: id.uppercased(), name: id.capitalized)
        }
    }

    func entities(matching string: String) async throws -> [CoinEntity] {
        try await WidgetDependencies.market.search(string)
            .prefix(20)
            .map { CoinEntity(result: $0) }
    }

    func suggestedEntities() async throws -> [CoinEntity] {
        try await WidgetDependencies.market.topCoins(forceRefresh: false).coins
            .map { CoinEntity(coin: $0) }
    }
}

struct SelectCoinIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Choose a coin"
    static var description = IntentDescription("Pick the coin this widget shows.")

    @Parameter(title: "Coin")
    var coin: CoinEntity?

    /// Bitcoin until the user picks something else.
    var coinID: String { coin?.id ?? "bitcoin" }
}

struct SelectWatchlistIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Choose coins"
    static var description = IntentDescription("Pick the three coins this widget shows.")

    @Parameter(title: "First coin")
    var first: CoinEntity?

    @Parameter(title: "Second coin")
    var second: CoinEntity?

    @Parameter(title: "Third coin")
    var third: CoinEntity?

    /// Bitcoin, Ethereum and Solana until the user picks others.
    var coinIDs: [String] {
        [first?.id ?? "bitcoin", second?.id ?? "ethereum", third?.id ?? "solana"]
    }
}
