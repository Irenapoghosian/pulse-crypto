import DesignSystem
import Localization
import SwiftUI

/// Appearance, language, data source and app info.
struct SettingsView: View {
    @AppStorage(AppearancePreference.storageKey) private var appearance: AppearancePreference = .system
    @AppStorage(AppLanguage.storageKey) private var language: AppLanguage = .system

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

            Section {
                Picker("Language", selection: $language) {
                    ForEach(AppLanguage.allCases) { option in
                        Text(option.title).tag(option)
                    }
                }
                .pickerStyle(.inline)
                .labelsHidden()
            } header: {
                Text("Language")
            } footer: {
                Text("Home Screen widgets follow your iPhone's language.")
            }

            Section("Market data") {
                LabeledContent("Source", value: "CoinGecko")
                LabeledContent("API access", value: AppConfig.coinGeckoAPIKey == nil ? Localized.string("Keyless") : Localized.string("Demo key"))
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
        .navigationTitle(Localized.string("Settings"))
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
