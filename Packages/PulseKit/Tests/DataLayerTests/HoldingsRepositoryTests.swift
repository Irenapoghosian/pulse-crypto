import Domain
import SwiftData
import XCTest
@testable import DataLayer

@MainActor
final class SwiftDataHoldingsRepositoryTests: XCTestCase {

    private let btc = CoinIdentity(id: "bitcoin", symbol: "BTC", name: "Bitcoin", imageURL: URL(string: "https://x/btc.png"))
    private let eth = CoinIdentity(id: "ethereum", symbol: "ETH", name: "Ethereum")

    private func makeRepository() throws -> SwiftDataHoldingsRepository {
        let container = try ModelContainer(
            for: HoldingRecord.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        var tick = 0.0
        return SwiftDataHoldingsRepository(container: container) {
            tick += 1
            return Date(timeIntervalSince1970: tick)
        }
    }

    func testSaveAndReadBackInInsertionOrder() async throws {
        let repository = try makeRepository()

        try await repository.save(Holding(coin: btc, amount: 0.5))
        try await repository.save(Holding(coin: eth, amount: 2))

        let all = try await repository.all()
        XCTAssertEqual(all, [Holding(coin: btc, amount: 0.5), Holding(coin: eth, amount: 2)])
        XCTAssertEqual(all.first?.coin.imageURL, btc.imageURL)
    }

    func testSavingAnExistingCoinUpdatesTheAmount() async throws {
        let repository = try makeRepository()

        try await repository.save(Holding(coin: btc, amount: 0.5))
        try await repository.save(Holding(coin: btc, amount: 1.25))

        let all = try await repository.all()
        XCTAssertEqual(all, [Holding(coin: btc, amount: 1.25)])
    }

    func testDelete() async throws {
        let repository = try makeRepository()
        try await repository.save(Holding(coin: btc, amount: 0.5))
        try await repository.save(Holding(coin: eth, amount: 2))

        try await repository.delete(coinID: "bitcoin")
        try await repository.delete(coinID: "not-held") // no-op

        let ids = try await repository.all().map(\.id)
        XCTAssertEqual(ids, ["ethereum"])
    }
}
