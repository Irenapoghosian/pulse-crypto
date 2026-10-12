import SwiftUI
import UIKit

/// `+2.45%` in a tinted capsule.
public struct ChangeBadge: View {
    let change: Double?

    public init(_ change: Double?) {
        self.change = change
    }

    public var body: some View {
        Text(change.map { PulseFormat.percentChange($0) } ?? "—")
            .font(.pulseNumber(.caption, weight: .semibold))
            .foregroundStyle(Color.trend(change))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.trend(change).opacity(0.14), in: Capsule())
            .accessibilityLabel(accessibilityText)
    }

    private var accessibilityText: String {
        PulseAccessibility.change(change) ?? "No change data"
    }
}

/// Coin logo with a lettered placeholder while loading or when there's no image.
public struct CoinIcon: View {
    let url: URL?
    let symbol: String
    let size: CGFloat
    @Environment(\.colorScheme) private var colorScheme

    public init(url: URL?, symbol: String, size: CGFloat = 36) {
        self.url = url
        self.symbol = symbol
        self.size = size
    }

    public var body: some View {
        AsyncImage(url: url, transaction: Transaction(animation: .easeOut(duration: 0.2))) { phase in
            if let image = phase.image {
                image.resizable().scaledToFit()
            } else {
                Circle()
                    .fill(Color.pulseAccent.opacity(0.15))
                    .overlay(
                        Text(symbol.prefix(1))
                            .font(.system(size: size * 0.42, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.pulseAccent)
                    )
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        // Some logos are dark on transparent (WhiteBIT, Hyperliquid); a faint
        // ring keeps them visible on a black background.
        .overlay {
            if colorScheme == .dark {
                Circle().strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
            }
        }
        .accessibilityHidden(true)
    }
}

/// A tiny line chart of recent prices, colored by direction.
public struct Sparkline: View {
    let values: [Double]

    public init(_ values: [Double]) {
        self.values = values
    }

    public var body: some View {
        let trend = (values.last ?? 0) - (values.first ?? 0)
        SparklineShape(values: values)
            .stroke(Color.trend(trend), style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))
            .accessibilityHidden(true)
    }
}

struct SparklineShape: Shape {
    let values: [Double]

    func path(in rect: CGRect) -> Path {
        var path = Path()
        guard values.count > 1, let low = values.min(), let high = values.max() else { return path }
        let span = max(high - low, .ulpOfOne)
        let step = rect.width / CGFloat(values.count - 1)

        for (index, value) in values.enumerated() {
            let point = CGPoint(
                x: CGFloat(index) * step,
                y: rect.maxY - CGFloat((value - low) / span) * rect.height
            )
            if index == 0 {
                path.move(to: point)
            } else {
                path.addLine(to: point)
            }
        }
        return path
    }
}

/// Full-screen error with a retry button.
public struct ErrorStateView: View {
    let title: String
    let message: String
    let retry: () -> Void

    public init(title: String = "Couldn't load prices", message: String, retry: @escaping () -> Void) {
        self.title = title
        self.message = message
        self.retry = retry
    }

    public var body: some View {
        ContentUnavailableView {
            Label(title, systemImage: "wifi.exclamationmark")
        } description: {
            Text(message)
        } actions: {
            Button("Try again", action: retry)
                .buttonStyle(.borderedProminent)
        }
    }
}

/// A slim notice shown above content, e.g. "Offline — showing prices from 10:42".
public struct NoticeBanner: View {
    let systemImage: String
    let text: String

    public init(systemImage: String, text: String) {
        self.systemImage = systemImage
        self.text = text
    }

    public var body: some View {
        Label(text, systemImage: systemImage)
            .font(.footnote.weight(.medium))
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
}

/// Label above a value, used in stat grids.
public struct StatTile: View {
    let title: String
    let value: String

    public init(_ title: String, value: String) {
        self.title = title
        self.value = value
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.pulseNumber(.subheadline, weight: .semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
        .accessibilityElement(children: .combine)
    }
}
