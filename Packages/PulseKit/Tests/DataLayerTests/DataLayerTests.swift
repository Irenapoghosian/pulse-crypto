import Domain
import Networking
import XCTest
@testable import DataLayer

// MARK: - Decoding and mapping

final class CoinGeckoMappingTests: XCTestCase {

    /// Trimmed copy of a real `/coins/markets` response, including nulls CoinGecko sends.
    static let marketsJSON = #"""
    [
      {
        "id": "bitcoin", "symbol": "btc", "name": "Bitcoin",
        "image": "https://assets.coingecko.com/coins/images/1/large/bitcoin.png",
        "current_price": 64210.55, "market_cap": 1265000000000, "market_cap_rank": 1,
        "fully_diluted_valuation": 1348000000000, "total_volume": 28400000000,
        "high_24h": 64900, "low_24h": 63010, "price_change_24h": 950.2,
        "price_change_percentage_24h": 1.502, "circulating_supply": 19700000,
        "total_supply": 21000000, "max_supply": 21000000, "ath": 73738,
        "roi": null, "last_updated": "2026-10-08T12:00:00.000Z",
        "sparkline_in_7d": { "price": [63000.1, null, 64000.2] },
        "price_change_percentage_24h_in_currency": 1.502
      },
      {
        "id": "new-token", "symbol": "new", "name": "New Token", "image": null,
        "current_price": null, "market_cap": null, "market_cap_rank": null,
        "total_volume": null, "high_24h": null, "low_24h": null,
        "price_change_percentage_24h": null, "ath": null, "circulating_supply": null,
        "sparkline_in_7d": null
      }
    ]
    """#

    func testDecodesMarketsAndDropsCoinsWithoutPrice() throws {
        let dtos = try Self.decode([CoinMarketDTO].self, Self.marketsJSON)
        let coins = dtos.compactMap { $0.toDomain() }

        XCTAssertEqual(dtos.count, 2)
        XCTAssertEqual(coins.count, 1)

        let btc = try XCTUnwrap(coins.first)
        XCTAssertEqual(btc.symbol, "BTC") // uppercased for display
        XCTAssertEqual(btc.price, 64210.55)
        XCTAssertEqual(btc.priceChange24h, 1.502)
        XCTAssertEqual(btc.marketCapRank, 1)
        XCTAssertEqual(btc.high24h, 64900) // regression: `_24h` keys used to decode as nil
        XCTAssertEqual(btc.low24h, 63010)
        XCTAssertEqual(btc.circulatingSupply, 19700000)
        XCTAssertEqual(btc.allTimeHigh, 73738)
        XCTAssertEqual(btc.sparkline7d, [63000.1, 64000.2]) // nulls skipped
        XCTAssertEqual(btc.imageURL?.host, "assets.coingecko.com")
    }

    func testSearchMapping() throws {
        let json = #"{"coins":[{"id":"pepe","name":"Pepe","api_symbol":"pepe","symbol":"PEPE","market_cap_rank":30,"thumb":"https://x/thumb.png","large":"https://x/large.png"}],"exchanges":[],"categories":[]}"#
        let result = try Self.decode(SearchResponseDTO.self, json).coins.map { $0.toDomain() }

        XCTAssertEqual(result, [CoinSearchResult(
            id: "pepe", symbol: "PEPE", name: "Pepe",
            thumbURL: URL(string: "https://x/large.png"), marketCapRank: 30
        )])
    }

    func testMarketChartMapping() throws {
        let json = #"{"prices":[[1760000000000,100.5],[1760003600000,101.25],[1760007200000]],"market_caps":[],"total_volumes":[]}"#
        let points = try Self.decode(MarketChartDTO.self, json).toDomain()

        XCTAssertEqual(points.map(\.price), [100.5, 101.25]) // malformed pair skipped
        XCTAssertEqual(points.first?.date, Date(timeIntervalSince1970: 1_760_000_000))
    }

    static func decode<T: Decodable>(_ type: T.Type, _ json: String) throws -> T {
        // Same configuration as CoinGeckoAPI: the DTOs declare their own keys.
        try JSONDecoder().decode(T.self, from: Data(json.utf8))
    }
}

// MARK: - Repository behavior

final class DefaultMarketRepositoryTests: XCTestCase {

    private let start = Date(timeIntervalSince1970: 1_760_000_000)

    func testFreshFetchIsCached() async throws {
        let http = ScriptedHTTPClient(responses: [.ok(CoinGeckoMappingTests.marketsJSON)])
        let cache = InMemoryMarketCache()
        let repository = makeRepository(http: http, cache: cache, now: start)

        let snapshot = try await repository.topCoins(forceRefresh: false)

        XCTAssertEqual(snapshot.coins.map(\.id), ["bitcoin"])
        XCTAssertFalse(snapshot.isFromCache)
        let saved = await cache.load()
        XCTAssertEqual(saved?.savedAt, start)
    }

    func testRecentCacheIsReusedWithoutNetwork() async throws {
        let http = ScriptedHTTPClient(responses: [])
        let cache = InMemoryMarketCache(try cachedMarket(savedAt: start))
        let repository = makeRepository(http: http, cache: cache, now: start.addingTimeInterval(30))

        let snapshot = try await repository.topCoins(forceRefresh: false)

        XCTAssertEqual(snapshot.coins.count, 1)
        XCTAssertFalse(snapshot.isFromCache)
        XCTAssertEqual(http.requestCount, 0)
    }

    func testForceRefreshIgnoresRecentCache() async throws {
        let http = ScriptedHTTPClient(responses: [.ok(CoinGeckoMappingTests.marketsJSON)])
        let cache = InMemoryMarketCache(try cachedMarket(savedAt: start))
        let repository = makeRepository(http: http, cache: cache, now: start.addingTimeInterval(30))

        _ = try await repository.topCoins(forceRefresh: true)

        XCTAssertEqual(http.requestCount, 1)
    }

    func testFallsBackToCacheWhenOffline() async throws {
        let http = ScriptedHTTPClient(responses: [.failure(URLError(.notConnectedToInternet))])
        let cache = InMemoryMarketCache(try cachedMarket(savedAt: start))
        let repository = makeRepository(http: http, cache: cache, now: start.addingTimeInterval(3600))

        let snapshot = try await repository.topCoins(forceRefresh: false)

        XCTAssertTrue(snapshot.isFromCache)
        XCTAssertEqual(snapshot.updatedAt, start)
    }

    func testErrorsAreTranslatedForTheUI() async {
        let cases: [(ScriptedHTTPClient.Response, MarketDataError)] = [
            (.failure(URLError(.notConnectedToInternet)), .offline),
            (.status(429), .rateLimited),
            (.status(500), .unavailable),
        ]
        for (response, expected) in cases {
            let repository = makeRepository(
                http: ScriptedHTTPClient(responses: [response]),
                cache: InMemoryMarketCache(),
                now: start
            )
            do {
                _ = try await repository.topCoins(forceRefresh: false)
                XCTFail("Expected \(expected)")
            } catch {
                XCTAssertEqual(error as? MarketDataError, expected)
            }
        }
    }

    func testRequestsUseApiKeyHeaderWhenProvided() async throws {
        let http = ScriptedHTTPClient(responses: [.ok("[]")])
        let repository = DefaultMarketRepository(
            api: CoinGeckoAPI(apiKey: "demo-key", http: http),
            cache: InMemoryMarketCache()
        )

        _ = try await repository.topCoins(forceRefresh: true)

        let request = try XCTUnwrap(http.lastRequest)
        XCTAssertEqual(request.value(forHTTPHeaderField: "x-cg-demo-api-key"), "demo-key")
        XCTAssertEqual(request.url?.path, "/api/v3/coins/markets")
        let query = request.url?.query ?? ""
        XCTAssertTrue(query.contains("sparkline=true"))
        XCTAssertTrue(query.contains("vs_currency=usd"))
    }

    func testCoinsByIDsJoinsIDs() async throws {
        let http = ScriptedHTTPClient(responses: [.ok(CoinGeckoMappingTests.marketsJSON)])
        let repository = makeRepository(http: http, cache: InMemoryMarketCache(), now: start)

        let coins = try await repository.coins(ids: ["bitcoin", "new-token"])

        XCTAssertEqual(coins.map(\.id), ["bitcoin"])
        XCTAssertTrue(http.lastRequest?.url?.query?.contains("ids=bitcoin,new-token") == true)
    }

    func testEmptyIDsSkipTheNetwork() async throws {
        let http = ScriptedHTTPClient(responses: [])
        let repository = makeRepository(http: http, cache: InMemoryMarketCache(), now: start)

        let coins = try await repository.coins(ids: [])

        XCTAssertTrue(coins.isEmpty)
        XCTAssertEqual(http.requestCount, 0)
    }

    func testFileCacheRoundTrip() async throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: url) }
        let market = try cachedMarket(savedAt: start)

        await FileMarketCache(fileURL: url).save(market)
        let loaded = await FileMarketCache(fileURL: url).load() // fresh instance reads from disk

        XCTAssertEqual(loaded, market)
    }

    // MARK: Helpers

    private func makeRepository(http: HTTPClient, cache: MarketCache, now: Date) -> DefaultMarketRepository {
        DefaultMarketRepository(
            api: CoinGeckoAPI(apiKey: nil, http: http),
            cache: cache,
            freshness: 60,
            now: { now }
        )
    }

    private func cachedMarket(savedAt: Date) throws -> CachedMarket {
        CachedMarket(
            coins: try CoinGeckoMappingTests.decode([CoinMarketDTO].self, CoinGeckoMappingTests.marketsJSON),
            savedAt: savedAt
        )
    }
}

/// Plays back responses in order and records requests.
final class ScriptedHTTPClient: HTTPClient, @unchecked Sendable {
    enum Response {
        case ok(String)
        case status(Int)
        case failure(Error)
    }

    private var responses: [Response]
    private(set) var requestCount = 0
    private(set) var lastRequest: URLRequest?

    init(responses: [Response]) {
        self.responses = responses
    }

    func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        requestCount += 1
        lastRequest = request
        guard !responses.isEmpty else {
            XCTFail("Unexpected request to \(request.url?.absoluteString ?? "?")")
            throw URLError(.badServerResponse)
        }
        let next = responses.removeFirst()
        let url = request.url!
        switch next {
        case .ok(let body):
            return (Data(body.utf8), HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!)
        case .status(let code):
            return (Data(), HTTPURLResponse(url: url, statusCode: code, httpVersion: nil, headerFields: nil)!)
        case .failure(let error):
            throw error
        }
    }
}
