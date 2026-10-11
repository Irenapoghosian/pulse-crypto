import Charts
import DesignSystem
import Domain
import SwiftUI

/// The portfolio tab. Rows push a `CoinIdentity`; the app decides what that opens.
public struct PortfolioView: View {
    @Bindable var model: PortfolioViewModel

    public init(model: PortfolioViewModel) {
        self.model = model
    }

    public var body: some View {
        content
            .navigationTitle("Portfolio")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        model.startAdding()
                    } label: {
                        Label("Add coin", systemImage: "plus")
                    }
                }
            }
            .sheet(item: $model.editor) { editor in
                NavigationStack {
                    HoldingEditorView(model: editor)
                }
                .presentationDetents([.large])
            }
            .task { await model.load() }
    }

    @ViewBuilder
    private var content: some View {
        switch model.state {
        case .loading:
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .failed(let message):
            ErrorStateView(title: "Something went wrong", message: message) {
                Task { await model.load() }
            }
        case .loaded where model.isEmpty:
            ContentUnavailableView {
                Label("No coins yet", systemImage: "briefcase")
            } description: {
                Text("Add the coins you own to see their total value and how it changes.")
            } actions: {
                Button("Add a coin") { model.startAdding() }
                    .buttonStyle(.borderedProminent)
            }
        case .loaded:
            list
        }
    }

    private var list: some View {
        List {
            Section {
                SummaryHeader(summary: model.summary, priceStatus: model.priceStatus)
                    // A small inset keeps the first letter out of the section's rounded-corner clip.
                    .listRowInsets(EdgeInsets(top: 4, leading: 4, bottom: 8, trailing: 4))
                    .listRowBackground(Color.clear)
            }

            if model.summary.allocation.count > 1 {
                Section("Allocation") {
                    AllocationChart(slices: model.summary.allocation)
                        .padding(.vertical, 8)
                }
            }

            Section("Holdings") {
                ForEach(model.summary.positions) { position in
                    NavigationLink(value: position.holding.coin) {
                        PositionRow(position: position)
                    }
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            Task { await model.delete(position.holding) }
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                        Button {
                            model.startEditing(position.holding)
                        } label: {
                            Label("Edit", systemImage: "pencil")
                        }
                        .tint(.pulseAccent)
                    }
                    .contextMenu {
                        Button("Edit amount", systemImage: "pencil") { model.startEditing(position.holding) }
                        Button("Remove", systemImage: "trash", role: .destructive) {
                            Task { await model.delete(position.holding) }
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .refreshable { await model.load() }
    }
}

// MARK: - Pieces

struct SummaryHeader: View {
    let summary: PortfolioSummary
    let priceStatus: PortfolioViewModel.PriceStatus

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Total balance")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text(PulseFormat.price(summary.totalValue))
                .font(.pulseNumber(.largeTitle, weight: .bold))
                .contentTransition(.numericText())
            HStack(spacing: 8) {
                ChangeBadge(summary.change24hPercent)
                Text(changeText)
                    .font(.pulseNumber(.subheadline, weight: .medium))
                    .foregroundStyle(Color.trend(summary.change24hValue))
                Text("24h")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if let notice {
                NoticeBanner(systemImage: "icloud.slash", text: notice)
                    .padding(.top, 6)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 8)
        .accessibilityElement(children: .combine)
    }

    private var changeText: String {
        let sign = summary.change24hValue >= 0 ? "+" : "−"
        return sign + PulseFormat.price(abs(summary.change24hValue))
    }

    private var notice: String? {
        switch priceStatus {
        case .live:
            return summary.isIncomplete ? "Some prices couldn't be loaded." : nil
        case .saved:
            return "Offline · using saved prices"
        case .unavailable:
            return "Prices unavailable · showing amounts only"
        }
    }
}

struct AllocationChart: View {
    let slices: [AllocationSlice]

    var body: some View {
        HStack(spacing: 20) {
            Chart(Array(slices.enumerated()), id: \.element.id) { index, slice in
                SectorMark(
                    angle: .value("Value", slice.value),
                    innerRadius: .ratio(0.62),
                    angularInset: 1.5
                )
                .cornerRadius(4)
                .foregroundStyle(color(at: index))
            }
            .frame(width: 130, height: 130)
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 8) {
                ForEach(Array(slices.enumerated()), id: \.element.id) { index, slice in
                    HStack(spacing: 8) {
                        Circle()
                            .fill(color(at: index))
                            .frame(width: 10, height: 10)
                        Text(slice.label)
                            .font(.subheadline.weight(.medium))
                        Spacer()
                        Text(slice.share.formatted(.percent.precision(.fractionLength(0...1))))
                            .font(.pulseNumber(.subheadline))
                            .foregroundStyle(.secondary)
                    }
                    .accessibilityElement(children: .combine)
                }
            }
        }
    }

    private func color(at index: Int) -> Color {
        let palette = Color.pulseChartPalette
        return palette[index % palette.count]
    }
}

struct PositionRow: View {
    let position: PortfolioPosition

    var body: some View {
        HStack(spacing: 12) {
            CoinIcon(url: position.coin?.imageURL ?? position.holding.coin.imageURL, symbol: position.holding.coin.symbol)

            VStack(alignment: .leading, spacing: 2) {
                Text(position.holding.coin.name)
                    .font(.body.weight(.semibold))
                    .lineLimit(1)
                Text("\(PulseFormat.amount(position.holding.amount)) \(position.holding.coin.symbol)")
                    .font(.pulseNumber(.caption))
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 4) {
                Text(position.value.map { PulseFormat.price($0) } ?? "—")
                    .font(.pulseNumber(.subheadline, weight: .semibold))
                ChangeBadge(position.coin?.priceChange24h)
            }
        }
        .padding(.vertical, 2)
    }
}
