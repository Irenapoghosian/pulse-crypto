import CoinDetailFeature
import DataLayer
import Domain
import Foundation
import MarketsFeature

/// The composition root: the only place that knows which concrete types
/// implement the Domain protocols. Features receive what they need through
/// their initializers, so tests and previews can pass fakes instead.
@MainActor
final class AppContainer {
    let marketRepository: MarketRepository

    /// Kept alive so the list survives tab switches.
    private(set) lazy var marketsViewModel = MarketsViewModel(repository: marketRepository)

    init(marketRepository: MarketRepository) {
        self.marketRepository = marketRepository
    }

    static func live() -> AppContainer {
        AppContainer(marketRepository: DefaultMarketRepository(apiKey: AppConfig.coinGeckoAPIKey))
    }

    func makeCoinDetailViewModel(for identity: CoinIdentity, coin: Coin? = nil) -> CoinDetailViewModel {
        CoinDetailViewModel(identity: identity, coin: coin, repository: marketRepository)
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
