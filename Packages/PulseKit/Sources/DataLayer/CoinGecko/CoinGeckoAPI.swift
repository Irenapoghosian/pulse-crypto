import Foundation
import Networking

/// The CoinGecko endpoints Pulse uses. Works without a key (shared, low rate limit);
/// a free "Demo" key from coingecko.com raises the limit.
struct CoinGeckoAPI: Sendable {
    static let baseURL = URL(string: "https://api.coingecko.com/api/v3")!

    private let client: APIClient

    init(apiKey: String?, http: HTTPClient) {
        var headers: [String: String] = [:]
        if let apiKey, !apiKey.isEmpty {
            headers["x-cg-demo-api-key"] = apiKey
        }
        // The DTOs spell out CoinGecko's keys: `.convertFromSnakeCase` turns
        // `high_24h` into `high24H` (capital H), which silently decodes as nil.
        client = APIClient(baseURL: Self.baseURL, http: http, headers: headers, keyDecodingStrategy: .useDefaultKeys)
    }

    func markets(ids: [String]? = nil, perPage: Int = 100) async throws -> [CoinMarketDTO] {
        var query = [
            URLQueryItem(name: "vs_currency", value: "usd"),
            URLQueryItem(name: "order", value: "market_cap_desc"),
            URLQueryItem(name: "per_page", value: String(perPage)),
            URLQueryItem(name: "page", value: "1"),
            URLQueryItem(name: "sparkline", value: "true"),
            URLQueryItem(name: "price_change_percentage", value: "24h"),
        ]
        if let ids {
            query.append(URLQueryItem(name: "ids", value: ids.joined(separator: ",")))
        }
        return try await client.get(Endpoint(path: "coins/markets", queryItems: query))
    }

    func search(_ query: String) async throws -> SearchResponseDTO {
        try await client.get(Endpoint(path: "search", queryItems: [URLQueryItem(name: "query", value: query)]))
    }

    func marketChart(id: String, days: Int) async throws -> MarketChartDTO {
        try await client.get(Endpoint(
            path: "coins/\(id)/market_chart",
            queryItems: [
                URLQueryItem(name: "vs_currency", value: "usd"),
                URLQueryItem(name: "days", value: String(days)),
            ]
        ))
    }
}
