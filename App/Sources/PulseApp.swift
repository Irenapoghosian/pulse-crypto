import DesignSystem
import SwiftUI
import UIKit

@main
struct PulseApp: App {
    /// Built once at launch; owns every long-lived dependency.
    @State private var container = AppContainer.live()
    @AppStorage(AppearancePreference.storageKey) private var appearance: AppearancePreference = .system

    var body: some Scene {
        WindowGroup {
            RootView(container: container)
                .onChange(of: appearance, initial: true) { _, newValue in
                    apply(newValue)
                }
        }
    }

    /// Sets the style on the window itself rather than with `preferredColorScheme`,
    /// which doesn't switch back to "System" reliably and misses sheets and alerts.
    private func apply(_ preference: AppearancePreference) {
        let windows = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
        for window in windows {
            window.overrideUserInterfaceStyle = preference.userInterfaceStyle
        }
    }
}
