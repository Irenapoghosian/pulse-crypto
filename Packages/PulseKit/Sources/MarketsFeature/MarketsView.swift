import DesignSystem
import Domain
import SwiftUI

/// The market list. Rows push a `CoinIdentity`; the app decides what screen that opens,
/// so this feature doesn't depend on the coin detail feature.
public struct MarketsView: View {
    @Bindable var model: MarketsViewModel

    public init(model: MarketsViewModel) {
        self.model = model
    }

    public var body: some View {
        content
            .navigationTitle("Markets")
            .searchable(text: $model.query, prompt: "Search coins")
            .toolbar { sortMenu }
            .task { await model.load() }
            .task(id: model.query) {
                // Debounce: wait for a pause in typing before hitting the network.
                try? await Task.sleep(for: .milliseconds(400))
                guard !Task.isCancelled else { return }
                await model.search()
            }
    }

    @ViewBuilder
    private var content: some View {
        switch model.state {
        case .loading:
            ProgressView("Loading prices…")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .failed(let message):
            ErrorStateView(message: message) {
                Task { await model.load() }
            }
        case .loaded:
            list
        }
    }

    private var list: some View {
        List {
            if model.isShowingCachedData, let date = model.snapshot?.updatedAt {
                NoticeBanner(
                    systemImage: "icloud.slash",
                    text: "Offline · prices from \(date.formatted(date: .omitted, time: .shortened))"
                )
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
            }

            Section {
                ForEach(model.visibleCoins) { coin in
                    NavigationLink(value: coin.identity) {
                        CoinRow(coin: coin)
                    }
                }
            }

            if !model.searchResults.isEmpty {
                Section("More results") {
                    ForEach(model.searchResults) { result in
                        NavigationLink(value: result.identity) {
                            SearchResultRow(result: result)
                        }
                    }
                }
            }

            if !model.query.isEmpty && model.visibleCoins.isEmpty && model.searchResults.isEmpty {
                if model.isSearching {
                    ProgressView().frame(maxWidth: .infinity)
                        .listRowSeparator(.hidden)
                } else {
                    ContentUnavailableView.search(text: model.query)
                        .listRowSeparator(.hidden)
                }
            }
        }
        .listStyle(.plain)
        .refreshable { await model.refresh() }
        .animation(.default, value: model.sort)
    }

    private var sortMenu: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Menu {
                Picker("Sort by", selection: $model.sort) {
                    ForEach(MarketSort.allCases) { sort in
                        Text(sort.title).tag(sort)
                    }
                }
            } label: {
                Label("Sort", systemImage: "arrow.up.arrow.down")
            }
            .accessibilityValue(model.sort.title)
        }
    }
}

struct CoinRow: View {
    let coin: Coin
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        Group {
            if typeSize.isAccessibilitySize {
                // Very large text: stack the pieces and drop the sparkline instead of truncating.
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 12) {
                        CoinIcon(url: coin.imageURL, symbol: coin.symbol)
                        name
                    }
                    Text(PulseFormat.price(coin.price))
                        .font(.pulseNumber(.body, weight: .semibold))
                    ChangeBadge(coin.priceChange24h)
                }
            } else {
                HStack(spacing: 12) {
                    CoinIcon(url: coin.imageURL, symbol: coin.symbol)
                    name

                    Spacer(minLength: 8)

                    Sparkline(coin.sparkline7d)
                        .frame(width: 56, height: 24)

                    VStack(alignment: .trailing, spacing: 4) {
                        Text(PulseFormat.price(coin.price))
                            .font(.pulseNumber(.subheadline, weight: .semibold))
                        ChangeBadge(coin.priceChange24h)
                    }
                    .frame(minWidth: 92, alignment: .trailing)
                }
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(PulseAccessibility.coinSummary(
            name: coin.name,
            symbol: coin.symbol,
            price: coin.price,
            change24h: coin.priceChange24h,
            rank: coin.marketCapRank,
            sparkline: coin.sparkline7d
        ))
    }

    private var name: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(coin.name)
                .font(.body.weight(.semibold))
                .lineLimit(typeSize.isAccessibilitySize ? 2 : 1)
            HStack(spacing: 6) {
                if let rank = coin.marketCapRank {
                    Text("\(rank)")
                        .font(.caption2.weight(.semibold))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(.quaternary, in: RoundedRectangle(cornerRadius: 4))
                }
                Text(coin.symbol)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

struct SearchResultRow: View {
    let result: CoinSearchResult

    var body: some View {
        HStack(spacing: 12) {
            CoinIcon(url: result.thumbURL, symbol: result.symbol, size: 30)
            VStack(alignment: .leading, spacing: 2) {
                Text(result.name).font(.body.weight(.medium))
                Text(result.symbol).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            if let rank = result.marketCapRank {
                Text("#\(rank)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel([result.name, result.symbol, result.marketCapRank.map { "rank \($0)" }]
            .compactMap { $0 }
            .joined(separator: ", "))
    }
}
