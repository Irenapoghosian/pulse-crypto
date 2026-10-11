## Pulse 1.0 — first release

A crypto market and portfolio tracker for iPhone, built with SwiftUI as a multi-module app with Clean Architecture, async/await and dependency injection.

### Features
- **Live markets.** The top 100 coins, each with price, 24h change and a 7-day sparkline. Sort by market cap, gainers, losers or volume.
- **Smart search.** Instant local filtering, plus debounced remote search for coins outside the top 100.
- **Interactive charts.** Swift Charts with 1D / 1W / 1M / 1Y ranges. Press and drag to scrub through prices.
- **Portfolio.** See your total balance, 24h profit/loss and an allocation donut chart. Holdings are stored on device with SwiftData.
- **Add from anywhere.** Every coin screen has an "Add to portfolio" button.
- **Works offline.** If the network fails, the app shows the cached market list and saved prices, with a clear notice.
- **Rate-limit friendly.** Data is reused for a minute, and the portfolio is priced from the shared market list.
- **Locale-aware input.** Amounts are accepted as both `0,5` and `0.5`.

### Under the hood
- Local Swift package **PulseKit**, split into 7 modules: Domain, Networking, DataLayer, DesignSystem, and one module each for Markets, Coin Detail and Portfolio.
- Features depend only on `Domain` protocols. The app's `AppContainer` is the single composition root.
- **76 unit tests** across every module. CI runs them on every push.

### Requirements
iOS 17+, Xcode 16+. A CoinGecko Demo API key is optional. See the README.

Market data provided by [CoinGecko](https://www.coingecko.com).
