import SwiftUI

@main
struct PulseApp: App {
    /// Built once at launch; owns every long-lived dependency.
    @State private var container = AppContainer.live()

    var body: some Scene {
        WindowGroup {
            RootView(container: container)
        }
    }
}
