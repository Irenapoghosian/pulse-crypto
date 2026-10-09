import Domain
import Foundation
import SwiftData

/// SwiftData row for one holding. Internal: the rest of the app only sees `Holding`.
@Model
final class HoldingRecord {
    @Attribute(.unique) var coinID: String
    var symbol: String
    var name: String
    var imageURLString: String?
    var amount: Double
    var addedAt: Date

    init(coinID: String, symbol: String, name: String, imageURLString: String?, amount: Double, addedAt: Date) {
        self.coinID = coinID
        self.symbol = symbol
        self.name = name
        self.imageURLString = imageURLString
        self.amount = amount
        self.addedAt = addedAt
    }

    var holding: Holding {
        Holding(
            coin: CoinIdentity(id: coinID, symbol: symbol, name: name, imageURL: imageURLString.flatMap { URL(string: $0) }),
            amount: amount
        )
    }
}

/// Stores holdings with SwiftData on the main context. The data set is tiny,
/// so the main actor keeps things simple and avoids cross-context syncing.
@MainActor
final class SwiftDataHoldingsRepository: HoldingsRepository {
    private let container: ModelContainer
    private let context: ModelContext
    private let now: () -> Date

    init(container: ModelContainer, now: @escaping () -> Date = { Date() }) {
        self.container = container
        self.context = container.mainContext
        self.now = now
    }

    func all() async throws -> [Holding] {
        let descriptor = FetchDescriptor<HoldingRecord>(sortBy: [SortDescriptor(\.addedAt)])
        return try context.fetch(descriptor).map(\.holding)
    }

    func save(_ holding: Holding) async throws {
        if let existing = try record(for: holding.id) {
            existing.amount = holding.amount
        } else {
            context.insert(HoldingRecord(
                coinID: holding.coin.id,
                symbol: holding.coin.symbol,
                name: holding.coin.name,
                imageURLString: holding.coin.imageURL?.absoluteString,
                amount: holding.amount,
                addedAt: now()
            ))
        }
        try context.save()
    }

    func delete(coinID: String) async throws {
        guard let existing = try record(for: coinID) else { return }
        context.delete(existing)
        try context.save()
    }

    private func record(for coinID: String) throws -> HoldingRecord? {
        var descriptor = FetchDescriptor<HoldingRecord>(predicate: #Predicate { $0.coinID == coinID })
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }
}

/// Builds persistence without exposing SwiftData to the app or the features.
public enum Persistence {

    @MainActor
    public static func holdingsRepository(inMemory: Bool = false) throws -> HoldingsRepository {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: inMemory)
        let container = try ModelContainer(for: HoldingRecord.self, configurations: configuration)
        return SwiftDataHoldingsRepository(container: container)
    }
}
