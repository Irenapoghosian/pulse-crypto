import Domain
import Foundation

// Shapes of CoinGecko's JSON, with the exact keys spelled out in `CodingKeys`.
// Almost everything is optional: CoinGecko returns `null` for new or obscure coins.

struct CoinMarketDTO: Codable, Equatable, Sendable {
    struct Sparkline: Codable, Equatable, Sendable {
        let price: [Double?]?
    }

    let id: String
    let symbol: String
    let name: String
    let image: String?
    let currentPrice: Double?
    let marketCap: Double?
    let marketCapRank: Int?
    let totalVolume: Double?
    let high24h: Double?
    let low24h: Double?
    let priceChangePercentage24h: Double?
    let ath: Double?
    let circulatingSupply: Double?
    let sparklineIn7d: Sparkline?

    enum CodingKeys: String, CodingKey {
        case id, symbol, name, image, ath
        case currentPrice = "current_price"
        case marketCap = "market_cap"
        case marketCapRank = "market_cap_rank"
        case totalVolume = "total_volume"
        case high24h = "high_24h"
        case low24h = "low_24h"
        case priceChangePercentage24h = "price_change_percentage_24h"
        case circulatingSupply = "circulating_supply"
        case sparklineIn7d = "sparkline_in_7d"
    }
}

struct SearchResponseDTO: Decodable, Sendable {
    struct CoinDTO: Decodable, Sendable {
        let id: String
        let name: String
        let symbol: String
        let marketCapRank: Int?
        let thumb: String?
        let large: String?

        enum CodingKeys: String, CodingKey {
            case id, name, symbol, thumb, large
            case marketCapRank = "market_cap_rank"
        }
    }

    let coins: [CoinDTO]
}

struct MarketChartDTO: Decodable, Sendable {
    /// `[[timestamp in ms, price], …]`
    let prices: [[Double]]
}

// MARK: - Mapping to the domain

extension CoinMarketDTO {
    /// Coins without a price can't be shown or valued, so they are dropped.
    func toDomain() -> Coin? {
        guard let currentPrice else { return nil }
        return Coin(
            id: id,
            symbol: symbol.uppercased(),
            name: name,
            imageURL: image.flatMap { URL(string: $0) },
            price: currentPrice,
            priceChange24h: priceChangePercentage24h,
            marketCap: marketCap,
            marketCapRank: marketCapRank,
            totalVolume: totalVolume,
            high24h: high24h,
            low24h: low24h,
            allTimeHigh: ath,
            circulatingSupply: circulatingSupply,
            sparkline7d: sparklineIn7d?.price?.compactMap { $0 } ?? []
        )
    }
}

extension SearchResponseDTO.CoinDTO {
    func toDomain() -> CoinSearchResult {
        CoinSearchResult(
            id: id,
            symbol: symbol.uppercased(),
            name: name,
            thumbURL: (large ?? thumb).flatMap { URL(string: $0) },
            marketCapRank: marketCapRank
        )
    }
}

extension MarketChartDTO {
    func toDomain() -> [PricePoint] {
        prices.compactMap { pair in
            guard pair.count >= 2 else { return nil }
            return PricePoint(date: Date(timeIntervalSince1970: pair[0] / 1000), price: pair[1])
        }
    }
}
