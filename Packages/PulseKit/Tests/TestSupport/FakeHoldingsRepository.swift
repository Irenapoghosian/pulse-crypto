import Domain
import Foundation

/// In-memory `HoldingsRepository` with the same upsert semantics as the real one.
public final class FakeHoldingsRepository: HoldingsRepository, @unchecked Sendable {
    public private(set) var stored: [Holding]
    public var failure: Error?

    public init(_ holdings: [Holding] = []) {
        stored = holdings
    }

    public func all() async throws -> [Holding] {
        if let failure { throw failure }
        return stored
    }

    public func save(_ holding: Holding) async throws {
        if let failure { throw failure }
        if let index = stored.firstIndex(where: { $0.id == holding.id }) {
            stored[index] = holding
        } else {
            stored.append(holding)
        }
    }

    public func delete(coinID: String) async throws {
        if let failure { throw failure }
        stored.removeAll { $0.id == coinID }
    }
}

public extension Fixtures {
    static func holding(_ coin: Coin, _ amount: Double) -> Holding {
        Holding(coin: coin.identity, amount: amount)
    }
}
