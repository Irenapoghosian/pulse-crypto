import CoinDetailFeature
import DataLayer
import Domain
import Foundation
import MarketsFeature
import PortfolioFeature

/// The composition root: the only place that knows which concrete types
/// implement the Domain protocols. Features receive what they need through
/// their initializers, so tests and previews can pass fakes instead.
@MainActor
final class AppContainer {
    let marketRepository: MarketRepository
    let holdingsRepository: HoldingsRepository

    /// Kept alive so each tab keeps its state when you switch away.
    private(set) lazy var marketsViewModel = MarketsViewModel(repository: marketRepository)
    private(set) lazy var portfolioViewModel = PortfolioViewModel(holdings: holdingsRepository, market: marketRepository)

    init(marketRepository: MarketRepository, holdingsRepository: HoldingsRepository) {
        self.marketRepository = marketRepository
        self.holdingsRepository = holdingsRepository
    }

    static func live() -> AppContainer {
        AppContainer(
            marketRepository: DefaultMarketRepository(apiKey: AppConfig.coinGeckoAPIKey),
            holdingsRepository: makeHoldingsRepository()
        )
    }

    func makeCoinDetailViewModel(for identity: CoinIdentity) -> CoinDetailViewModel {
        // Reuse market data we already have so the header shows instantly.
        let coin = marketsViewModel.snapshot?.coins.first { $0.id == identity.id }
        return CoinDetailViewModel(identity: identity, coin: coin, repository: marketRepository)
    }

    /// Adds the coin to the portfolio, or edits the amount if it's already there.
    func makeHoldingEditor(for identity: CoinIdentity) -> HoldingEditorViewModel {
        portfolioViewModel.makeEditor(for: identity)
    }

    private static func makeHoldingsRepository() -> HoldingsRepository {
        do {
            return try Persistence.holdingsRepository()
        } catch {
            // A broken store shouldn't stop the app from launching; fall back to memory.
            assertionFailure("Couldn't open the holdings store: \(error)")
            // swiftlint:disable:next force_try
            return try! Persistence.holdingsRepository(inMemory: true)
        }
    }
}

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
