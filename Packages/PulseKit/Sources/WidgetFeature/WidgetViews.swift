import DesignSystem
import Domain
import SwiftUI
import UIKit
import WidgetKit

// MARK: - Small: one coin

/// Price, 24h change and the 7-day line for one coin. Tapping opens the coin in the app.
public struct CoinWidgetView: View {
    let entry: MarketEntry

    public init(entry: MarketEntry) {
        self.entry = entry
    }

    public var body: some View {
        if let item = entry.coins.first {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    WidgetCoinIcon(item: item, size: 22)
                    Text(item.coin.symbol)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                    Spacer(minLength: 0)
                    StaleIndicator(isStale: entry.isStale)
                    // The line covers 7 days while the badge is 24h, so say which is which.
                    Text("7D")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 0)

                Sparkline(item.coin.sparkline7d)
                    .frame(height: 36)

                Spacer(minLength: 0)

                Text(PulseFormat.price(item.coin.price))
                    .font(.system(.title2, design: .rounded, weight: .bold).monospacedDigit())
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                ChangeBadge(item.coin.priceChange24h)
            }
            .widgetURL(CoinLink.url(for: item.coin.identity))
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(WidgetAccessibility.label(for: item.coin))
        } else {
            WidgetUnavailableView()
        }
    }
}

// MARK: - Medium: watchlist

/// Up to three coins, each row opening its coin in the app.
public struct WatchlistWidgetView: View {
    let entry: MarketEntry

    public init(entry: MarketEntry) {
        self.entry = entry
    }

    private var items: [WidgetCoin] { Array(entry.coins.prefix(3)) }

    public var body: some View {
        if items.isEmpty {
            WidgetUnavailableView()
        } else {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 4) {
                    Text("Pulse")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Color.pulseAccent)
                    Spacer()
                    StaleIndicator(isStale: entry.isStale)
                    Text(entry.date, style: .time)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .padding(.bottom, 2)

                ForEach(items) { item in
                    Link(destination: CoinLink.url(for: item.coin.identity)) {
                        WatchlistRow(item: item)
                    }
                    if item.id != items.last?.id {
                        Divider()
                    }
                }
            }
        }
    }
}

struct WatchlistRow: View {
    let item: WidgetCoin

    var body: some View {
        HStack(spacing: 10) {
            WidgetCoinIcon(item: item, size: 26)

            VStack(alignment: .leading, spacing: 1) {
                Text(item.coin.name)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                Text(item.coin.symbol)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 8)

            Sparkline(item.coin.sparkline7d)
                .frame(width: 56, height: 22)

            VStack(alignment: .trailing, spacing: 2) {
                Text(PulseFormat.price(item.coin.price))
                    .font(.pulseNumber(.subheadline, weight: .semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text(item.coin.priceChange24h.map { PulseFormat.percentChange($0) } ?? "—")
                    .font(.pulseNumber(.caption2, weight: .semibold))
                    .foregroundStyle(Color.trend(item.coin.priceChange24h))
            }
            .frame(minWidth: 84, alignment: .trailing)
        }
        .frame(maxHeight: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(WidgetAccessibility.label(for: item.coin))
    }
}

// MARK: - Pieces

/// The logo from downloaded data, or the symbol's first letter.
struct WidgetCoinIcon: View {
    let item: WidgetCoin
    let size: CGFloat

    var body: some View {
        Group {
            if let data = item.iconData, let image = UIImage(data: data) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
            } else {
                Circle()
                    .fill(Color.pulseAccent.opacity(0.15))
                    .overlay(
                        Text(item.coin.symbol.prefix(1))
                            .font(.system(size: size * 0.45, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.pulseAccent)
                    )
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .accessibilityHidden(true)
    }
}

/// A small cloud icon when the prices are saved ones, not live.
struct StaleIndicator: View {
    let isStale: Bool

    var body: some View {
        if isStale {
            Image(systemName: "icloud.slash")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .accessibilityLabel("Offline, showing saved prices")
        }
    }
}

struct WidgetUnavailableView: View {
    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.title3)
                .foregroundStyle(Color.pulseAccent)
            Text("Prices unavailable")
                .font(.caption.weight(.semibold))
            Text("Open Pulse to refresh")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

enum WidgetAccessibility {
    /// "Bitcoin, $82,906.00, up 1.42%" — one sentence instead of separate pieces.
    static func label(for coin: Coin) -> String {
        var parts = [coin.name, PulseFormat.price(coin.price)]
        if let change = coin.priceChange24h {
            let magnitude = (abs(change) / 100).formatted(.percent.precision(.fractionLength(2)))
            parts.append((change >= 0 ? "up " : "down ") + magnitude + " today")
        }
        return parts.joined(separator: ", ")
    }
}
