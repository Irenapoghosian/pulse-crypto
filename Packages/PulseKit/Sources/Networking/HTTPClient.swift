import Foundation

/// The single seam between the app and the network. Tests swap in a stub.
public protocol HTTPClient: Sendable {
    func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse)
}

public struct URLSessionHTTPClient: HTTPClient {
    private let session: URLSession

    public init(session: URLSession = .shared) {
        self.session = session
    }

    public func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw NetworkError.invalidResponse }
        return (data, http)
    }
}

public enum NetworkError: Error, Equatable, Sendable {
    case offline
    case invalidResponse
    /// HTTP 429. `retryAfter` comes from the `Retry-After` header when present.
    case rateLimited(retryAfter: TimeInterval?)
    case status(Int)
    case decoding(String)
}
