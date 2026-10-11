import DesignSystem
import Domain
import SwiftUI

/// Sheet for adding a coin or changing an amount. Embed it in a `NavigationStack`.
public struct HoldingEditorView: View {
    @Bindable var model: HoldingEditorViewModel
    @Environment(\.dismiss) private var dismiss
    @FocusState private var amountFocused: Bool

    public init(model: HoldingEditorViewModel) {
        self.model = model
    }

    public var body: some View {
        Form {
            if let coin = model.selectedCoin {
                selectedCoinSection(coin)
                amountSection
            } else {
                pickerSection
            }

            if let error = model.errorMessage {
                Section {
                    Label(error, systemImage: "exclamationmark.triangle")
                        .foregroundStyle(Color.pulseDown)
                }
            }
        }
        .navigationTitle(model.mode == .add ? "Add coin" : "Edit holding")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    Task {
                        if await model.save() { dismiss() }
                    }
                }
                .disabled(!model.canSave)
            }
        }
        .task { await model.loadSuggestions() }
        .task(id: model.query) {
            try? await Task.sleep(for: .milliseconds(350))
            guard !Task.isCancelled else { return }
            await model.search()
        }
        .onChange(of: model.selectedCoin) { _, coin in
            if coin != nil { amountFocused = true }
        }
        .sensoryFeedback(.success, trigger: model.isSaving) { wasSaving, isSaving in
            wasSaving && !isSaving && model.errorMessage == nil
        }
    }

    // MARK: Sections

    private func selectedCoinSection(_ coin: CoinIdentity) -> some View {
        Section("Coin") {
            HStack(spacing: 12) {
                CoinIcon(url: coin.imageURL, symbol: coin.symbol, size: 32)
                VStack(alignment: .leading, spacing: 2) {
                    Text(coin.name).font(.body.weight(.semibold))
                    Text(coin.symbol).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                if model.canChangeCoin {
                    Button("Change") { model.clearSelection() }
                        .font(.subheadline)
                }
            }
        }
    }

    private var amountSection: some View {
        Section {
            TextField("0.00", text: $model.amountText)
                .keyboardType(.decimalPad)
                .font(.pulseNumber(.title2, weight: .semibold))
                .focused($amountFocused)
        } header: {
            Text("Amount")
        } footer: {
            if let value = model.estimatedValue {
                Text("≈ \(PulseFormat.price(value))")
                    .font(.pulseNumber(.footnote))
            } else if !model.amountText.isEmpty && model.amount == nil {
                Text("Enter a number greater than zero.")
                    .foregroundStyle(Color.pulseDown)
            }
        }
    }

    private var pickerSection: some View {
        Section {
            HStack {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                TextField("Search coins", text: $model.query)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            }

            if model.suggestions.isEmpty {
                Text(model.query.isEmpty ? "Loading coins…" : "No matches")
                    .foregroundStyle(.secondary)
            }

            ForEach(model.suggestions) { coin in
                Button {
                    model.select(coin)
                } label: {
                    HStack(spacing: 12) {
                        CoinIcon(url: coin.imageURL, symbol: coin.symbol, size: 28)
                        Text(coin.name).foregroundStyle(Color.primary)
                        Text(coin.symbol).font(.caption).foregroundStyle(Color.secondary)
                        Spacer()
                    }
                    .contentShape(Rectangle())
                }
                // Default Form buttons tint their whole label with the accent color.
                .buttonStyle(.plain)
            }
        } header: {
            Text("Choose a coin")
        }
    }
}
