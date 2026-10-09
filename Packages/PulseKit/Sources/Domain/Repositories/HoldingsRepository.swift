import Foundation

/// Where the user's holdings are stored. Implemented with SwiftData in `DataLayer`.
public protocol HoldingsRepository: Sendable {
    /// All holdings, oldest first.
    func all() async throws -> [Holding]
    /// Adds the holding, or replaces the amount if the coin is already held.
    func save(_ holding: Holding) async throws
    func delete(coinID: String) async throws
}
