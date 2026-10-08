import CoinDetailFeature
import Domain
import MarketsFeature
import SwiftUI

struct RootView: View {
    let container: AppContainer

    var body: some View {
        TabView {
            NavigationStack {
                MarketsView(model: container.marketsViewModel)
                    .withCoinDestination(container)
            }
            .tabItem { Label("Markets", systemImage: "chart.line.uptrend.xyaxis") }

            NavigationStack {
                ContentUnavailableView(
                    "Portfolio is coming next",
                    systemImage: "briefcase",
                    description: Text("Track your holdings and their value in the next update.")
                )
                .navigationTitle("Portfolio")
            }
            .tabItem { Label("Portfolio", systemImage: "briefcase") }
        }
    }
}

private extension View {
    /// Every tab's stack opens the same detail screen for a `CoinIdentity`.
    func withCoinDestination(_ container: AppContainer) -> some View {
        navigationDestination(for: CoinIdentity.self) { identity in
            CoinDetailScreen(container: container, identity: identity)
        }
    }
}

/// Creates the detail view model once per pushed screen.
private struct CoinDetailScreen: View {
    @State private var model: CoinDetailViewModel

    init(container: AppContainer, identity: CoinIdentity) {
        let coin = container.marketsViewModel.snapshot?.coins.first { $0.id == identity.id }
        _model = State(initialValue: container.makeCoinDetailViewModel(for: identity, coin: coin))
    }

    var body: some View {
        CoinDetailView(model: model)
    }
}
