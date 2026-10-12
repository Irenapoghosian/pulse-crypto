import DesignSystem
import SwiftUI

/// Appearance, data source and app info.
struct SettingsView: View {
    @AppStorage(AppearancePreference.storageKey) private var appearance: AppearancePreference = .system

    var body: some View {
        Form {
            Section {
                Picker("Appearance", selection: $appearance) {
                    ForEach(AppearancePreference.allCases) { option in
                        Label(option.title, systemImage: option.systemImage)
                            .tag(option)
                    }
                }
                .pickerStyle(.inline)
                .labelsHidden()
            } header: {
                Text("Appearance")
            } footer: {
                Text("System follows your iPhone's Light or Dark setting. Home Screen widgets always follow the system.")
            }

            Section("Market data") {
                LabeledContent("Source", value: "CoinGecko")
                LabeledContent("API access", value: AppConfig.coinGeckoAPIKey == nil ? "Keyless" : "Demo key")
                Link(destination: Self.coinGeckoURL) {
                    Label("Visit CoinGecko", systemImage: "arrow.up.right.square")
                }
            }

            Section("About") {
                LabeledContent("Version", value: Self.version)
                Link(destination: Self.sourceURL) {
                    Label("Source code on GitHub", systemImage: "chevron.left.forwardslash.chevron.right")
                }
            }
        }
        .navigationTitle("Settings")
    }

    private static let coinGeckoURL = URL(string: "https://www.coingecko.com")!
    private static let sourceURL = URL(string: "https://github.com/Irenapoghosian/pulse-crypto")!

    /// "1.0.0 (1)"
    private static var version: String {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? "—"
        let build = info?["CFBundleVersion"] as? String ?? "—"
        return "\(short) (\(build))"
    }
}

#Preview {
    NavigationStack {
        SettingsView()
    }
}
