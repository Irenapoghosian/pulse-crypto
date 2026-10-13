import Domain
import Foundation
import Localization
import Observation

@MainActor
@Observable
public final class CoinDetailViewModel {

    public enum ChartState: Equatable {
        case loading
        case loaded([PricePoint])
        case failed(String)
    }

    // MARK: State

    public let identity: CoinIdentity
    /// Full market data. Starts nil when the screen is opened from a search result.
    public private(set) var coin: Coin?
    public private(set) var chart: ChartState = .loading
    public private(set) var range: ChartRange = .week
    /// The point under the user's finger while scrubbing the chart.
    public var selectedDate: Date?

    public var points: [PricePoint] {
        if case .loaded(let points) = chart { return points }
        return []
    }

    public var selectedPoint: PricePoint? {
        guard let selectedDate, !points.isEmpty else { return nil }
        return points.min { abs($0.date.timeIntervalSince(selectedDate)) < abs($1.date.timeIntervalSince(selectedDate)) }
    }

    /// The headline price: the scrubbed point, otherwise the live price.
    public var displayedPrice: Double? {
        selectedPoint?.price ?? coin?.price ?? points.last?.price
    }

    /// Change across the visible range (or up to the scrubbed point).
    public var displayedChange: Double? {
        guard let first = points.first else { return coin?.priceChange24h }
        let endPoints = selectedPoint.map { [first, $0] } ?? [first, points[points.count - 1]]
        return MarketRules.change(over: endPoints)
    }

    // MARK: Dependencies

    private let repository: MarketRepository
    private var cache: [ChartRange: [PricePoint]] = [:]

    public init(identity: CoinIdentity, coin: Coin? = nil, repository: MarketRepository) {
        self.identity = identity
        self.coin = coin
        self.repository = repository
    }

    // MARK: Intents

    public func load() async {
        async let chartLoad: Void = loadChart(for: range)
        if coin == nil {
            coin = try? await repository.coins(ids: [identity.id]).first
        }
        await chartLoad
    }

    public func select(_ newRange: ChartRange) async {
        guard newRange != range else { return }
        range = newRange
        selectedDate = nil
        await loadChart(for: newRange)
    }

    // MARK: Private

    private func loadChart(for range: ChartRange) async {
        if let cached = cache[range] {
            chart = .loaded(cached)
            return
        }
        chart = .loading
        do {
            let points = try await repository.priceHistory(for: identity.id, range: range)
            cache[range] = points
            // The user may have switched ranges while this was loading.
            guard range == self.range else { return }
            chart = points.isEmpty ? .failed(Localized.string("No price history for this period.")) : .loaded(points)
        } catch is CancellationError {
            return
        } catch {
            guard range == self.range else { return }
            chart = .failed(Self.message(for: error))
        }
    }

    static func message(for error: Error) -> String {
        switch error as? MarketDataError {
        case .offline?: Localized.string("You're offline.")
        case .rateLimited?: Localized.string("Too many requests. Try again in a minute.")
        default: Localized.string("Couldn't load the chart.")
        }
    }
}
