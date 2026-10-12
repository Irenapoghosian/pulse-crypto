import CoinDetailFeature
import Domain
import MarketsFeature
import PortfolioFeature
import SwiftUI

struct RootView: View {
    let container: AppContainer
    @State private var selectedTab = RootTab.markets
    @State private var marketsPath: [CoinIdentity] = []

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack(path: $marketsPath) {
                MarketsView(model: container.marketsViewModel)
                    .withCoinDestination(container)
            }
            .tabItem { Label("Markets", systemImage: "chart.line.uptrend.xyaxis") }
            .tag(RootTab.markets)

            NavigationStack {
                PortfolioView(model: container.portfolioViewModel)
                    .withCoinDestination(container)
            }
            .tabItem { Label("Portfolio", systemImage: "briefcase") }
            .tag(RootTab.portfolio)

            NavigationStack {
                SettingsView()
            }
            .tabItem { Label("Settings", systemImage: "gearshape") }
            .tag(RootTab.settings)
        }
        // Load holdings at launch so "Add to portfolio" on any coin knows what's already owned.
        .task { await container.portfolioViewModel.load() }
        // Widgets open `pulse://coin/<id>`: show that coin on the Markets tab.
        .onOpenURL { url in
            guard let identity = CoinLink.identity(from: url) else { return }
            selectedTab = .markets
            marketsPath = [identity]
        }
    }
}

enum RootTab: Hashable {
    case markets
    case portfolio
    case settings
}

private extension View {
    /// Every tab's stack opens the same detail screen for a `CoinIdentity`.
    func withCoinDestination(_ container: AppContainer) -> some View {
        navigationDestination(for: CoinIdentity.self) { identity in
            CoinDetailScreen(container: container, identity: identity)
        }
    }
}

/// The coin detail feature plus an "Add to portfolio" action from the portfolio
/// feature. The two features never import each other; they meet only here.
private struct CoinDetailScreen: View {
    let container: AppContainer
    let identity: CoinIdentity
    @State private var model: CoinDetailViewModel
    @State private var editor: HoldingEditorViewModel?

    init(container: AppContainer, identity: CoinIdentity) {
        self.container = container
        self.identity = identity
        _model = State(initialValue: container.makeCoinDetailViewModel(for: identity))
    }

    var body: some View {
        CoinDetailView(model: model)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        editor = container.makeHoldingEditor(for: identity)
                    } label: {
                        Label(isOwned ? "Edit holding" : "Add to portfolio",
                              systemImage: isOwned ? "briefcase.fill" : "plus.circle")
                    }
                }
            }
            .sheet(item: $editor) { editor in
                NavigationStack {
                    HoldingEditorView(model: editor)
                }
            }
    }

    private var isOwned: Bool {
        container.portfolioViewModel.holding(for: identity.id) != nil
    }
}
