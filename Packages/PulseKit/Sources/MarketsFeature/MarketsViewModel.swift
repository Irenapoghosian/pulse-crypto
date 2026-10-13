import Domain
import Foundation
import Localization
import Observation

@MainActor
@Observable
public final class MarketsViewModel {

    public enum State: Equatable {
        case loading
        case loaded
        case failed(String)
    }

    // MARK: State

    public private(set) var state: State = .loading
    public private(set) var snapshot: MarketSnapshot?
    public private(set) var searchResults: [CoinSearchResult] = []
    public private(set) var isSearching = false

    public var query = ""
    public var sort: MarketSort = .rank

    /// What the list shows: the top coins, filtered by the query and sorted.
    public var visibleCoins: [Coin] {
        let coins = snapshot?.coins ?? []
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        // While searching, relevance beats the chosen sort.
        return trimmed.isEmpty
            ? MarketRules.sort(coins, by: sort)
            : MarketRules.filter(coins, query: trimmed)
    }

    public var isShowingCachedData: Bool { snapshot?.isFromCache == true }

    // MARK: Dependencies

    private let repository: MarketRepository
    private let searchCoins: SearchCoinsUseCase

    public init(repository: MarketRepository) {
        self.repository = repository
        self.searchCoins = SearchCoinsUseCase(repository: repository)
    }

    // MARK: Intents

    /// First load; shows the spinner only when there's nothing on screen yet.
    public func load() async {
        if snapshot == nil { state = .loading }
        await fetch(forceRefresh: false)
    }

    /// Pull to refresh.
    public func refresh() async {
        await fetch(forceRefresh: true)
    }

    /// Called whenever the query changes. The view debounces it.
    public func search() async {
        let shown = Set(visibleCoins.map(\.id))
        let current = query
        guard current.trimmingCharacters(in: .whitespaces).count >= 2 else {
            searchResults = []
            return
        }
        isSearching = true
        defer { isSearching = false }
        do {
            let results = try await searchCoins(current, excluding: shown)
            // Ignore late answers for a query the user has already changed.
            guard current == query else { return }
            searchResults = results
        } catch {
            // Search is a bonus on top of the local list; failing quietly is fine.
            if !(error is CancellationError) { searchResults = [] }
        }
    }

    // MARK: Private

    private func fetch(forceRefresh: Bool) async {
        do {
            snapshot = try await repository.topCoins(forceRefresh: forceRefresh)
            state = .loaded
        } catch is CancellationError {
            return
        } catch {
            // Keep showing whatever we had; only replace an empty screen with the error.
            if snapshot == nil {
                state = .failed(Self.message(for: error))
            }
        }
    }

    static func message(for error: Error) -> String {
        switch error as? MarketDataError {
        case .offline?:
            Localized.string("You're offline. Connect to the internet to see live prices.")
        case .rateLimited?:
            Localized.string("Too many requests right now. Please wait a minute and try again.")
        default:
            Localized.string("The price service isn't responding. Please try again.")
        }
    }
}
