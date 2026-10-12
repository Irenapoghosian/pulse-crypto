import Accessibility
import Charts
import DesignSystem
import Domain
import SwiftUI
import UIKit

public struct CoinDetailView: View {
    @Bindable var model: CoinDetailViewModel

    public init(model: CoinDetailViewModel) {
        self.model = model
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                chartSection
                rangePicker
                stats
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(model.identity.symbol)
        .navigationBarTitleDisplayMode(.inline)
        .task { await model.load() }
        .sensoryFeedback(.selection, trigger: model.selectedPoint?.date)
    }

    // MARK: Header

    private var header: some View {
        HStack(alignment: .center, spacing: 14) {
            CoinIcon(url: model.coin?.imageURL ?? model.identity.imageURL, symbol: model.identity.symbol, size: 48)
            VStack(alignment: .leading, spacing: 4) {
                Text(model.identity.name)
                    .font(.headline)
                    .foregroundStyle(.secondary)
                if let price = model.displayedPrice {
                    Text(PulseFormat.price(price))
                        .font(.pulseNumber(.largeTitle, weight: .bold))
                        .contentTransition(.numericText())
                        .animation(.snappy, value: price)
                } else {
                    Text("—").font(.pulseNumber(.largeTitle, weight: .bold))
                }
                HStack(spacing: 8) {
                    ChangeBadge(model.displayedChange)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var subtitle: String {
        if let point = model.selectedPoint {
            return point.date.formatted(date: .abbreviated, time: model.range == .day ? .shortened : .omitted)
        }
        return model.points.isEmpty ? "24h" : "Past \(model.range.title)"
    }

    // MARK: Chart

    @ViewBuilder
    private var chartSection: some View {
        Group {
            switch model.chart {
            case .loading:
                ProgressView()
            case .failed(let message):
                Label(message, systemImage: "chart.line.downtrend.xyaxis")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            case .loaded(let points):
                PriceChart(points: points, selectedDate: $model.selectedDate)
            }
        }
        .frame(height: 240)
        .frame(maxWidth: .infinity)
    }

    private var rangePicker: some View {
        Picker("Range", selection: Binding(
            get: { model.range },
            set: { newValue in Task { await model.select(newValue) } }
        )) {
            ForEach(ChartRange.allCases) { range in
                Text(range.title).tag(range)
            }
        }
        .pickerStyle(.segmented)
        .accessibilityLabel("Chart range")
    }

    // MARK: Stats

    @ViewBuilder
    private var stats: some View {
        if let coin = model.coin {
            VStack(alignment: .leading, spacing: 10) {
                Text("Market stats").font(.headline)
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    StatTile("Market cap", value: coin.marketCap.map { PulseFormat.compactCurrency($0) } ?? "—")
                    StatTile("Rank", value: coin.marketCapRank.map { "#\($0)" } ?? "—")
                    StatTile("Volume 24h", value: coin.totalVolume.map { PulseFormat.compactCurrency($0) } ?? "—")
                    StatTile("Supply", value: coin.circulatingSupply.map { PulseFormat.compactNumber($0) } ?? "—")
                    StatTile("High 24h", value: coin.high24h.map { PulseFormat.price($0) } ?? "—")
                    StatTile("Low 24h", value: coin.low24h.map { PulseFormat.price($0) } ?? "—")
                    StatTile("All-time high", value: coin.allTimeHigh.map { PulseFormat.price($0) } ?? "—")
                    StatTile("From ATH", value: coin.allTimeHigh.map { ath in
                        PulseFormat.percentChange((coin.price - ath) / ath * 100)
                    } ?? "—")
                }
            }
        }
    }
}

/// Line + gradient area chart with press-and-drag scrubbing.
struct PriceChart: View {
    let points: [PricePoint]
    @Binding var selectedDate: Date?

    private var trendColor: Color {
        Color.trend(MarketRules.change(over: points))
    }

    private var yDomain: ClosedRange<Double> {
        let prices = points.map(\.price)
        guard let low = prices.min(), let high = prices.max() else { return 0...1 }
        let padding = max((high - low) * 0.08, high * 0.001)
        return (low - padding)...(high + padding)
    }

    var body: some View {
        Chart {
            ForEach(points, id: \.date) { point in
                AreaMark(
                    x: .value("Date", point.date),
                    yStart: .value("Base", yDomain.lowerBound),
                    yEnd: .value("Price", point.price)
                )
                .foregroundStyle(
                    LinearGradient(
                        colors: [trendColor.opacity(0.28), trendColor.opacity(0)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .interpolationMethod(.monotone)

                LineMark(x: .value("Date", point.date), y: .value("Price", point.price))
                    .foregroundStyle(trendColor)
                    .lineStyle(StrokeStyle(lineWidth: 2))
                    .interpolationMethod(.monotone)
            }

            if let selectedDate {
                RuleMark(x: .value("Selected", selectedDate))
                    .foregroundStyle(.secondary.opacity(0.6))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))
            }
        }
        .chartYScale(domain: yDomain)
        .chartXAxis(.hidden)
        .chartYAxis {
            AxisMarks(position: .trailing, values: .automatic(desiredCount: 4)) { value in
                AxisGridLine().foregroundStyle(.quaternary)
                AxisValueLabel {
                    if let price = value.as(Double.self) {
                        Text(PulseFormat.compactCurrency(price))
                    }
                }
            }
        }
        .chartXSelection(value: $selectedDate)
        .accessibilityLabel("Price chart")
        .accessibilityValue(accessibilitySummary)
        // Lets VoiceOver users explore the chart as an Audio Graph.
        .accessibilityChartDescriptor(self)
    }

    /// "From $81,200.00 to $83,532.00, up 2.87%, low $80,950.00, high $86,410.00"
    var accessibilitySummary: String {
        guard let first = points.first, let last = points.last else { return "No data" }
        var parts = ["From \(PulseFormat.price(first.price)) to \(PulseFormat.price(last.price))"]
        if let change = PulseAccessibility.change(MarketRules.change(over: points)) {
            parts.append(change)
        }
        let prices = points.map(\.price)
        if let low = prices.min(), let high = prices.max() {
            parts.append("low \(PulseFormat.price(low)), high \(PulseFormat.price(high))")
        }
        return parts.joined(separator: ", ")
    }
}

extension PriceChart: AXChartDescriptorRepresentable {
    func makeChartDescriptor() -> AXChartDescriptor {
        let times = points.map { $0.date.timeIntervalSince1970 }
        let prices = points.map(\.price)
        let now = Date().timeIntervalSince1970

        let xAxis = AXNumericDataAxisDescriptor(
            title: "Date",
            range: (times.min() ?? now)...(times.max() ?? now),
            gridlinePositions: []
        ) { value in
            Date(timeIntervalSince1970: value).formatted(date: .abbreviated, time: .shortened)
        }

        let yAxis = AXNumericDataAxisDescriptor(
            title: "Price",
            range: (prices.min() ?? 0)...(prices.max() ?? 0),
            gridlinePositions: []
        ) { value in
            PulseFormat.price(value)
        }

        let series = AXDataSeriesDescriptor(
            name: "Price",
            isContinuous: true,
            dataPoints: points.map { AXDataPoint(x: $0.date.timeIntervalSince1970, y: $0.price) }
        )

        return AXChartDescriptor(
            title: "Price chart",
            summary: accessibilitySummary,
            xAxis: xAxis,
            yAxis: yAxis,
            additionalAxes: [],
            series: [series]
        )
    }
}
