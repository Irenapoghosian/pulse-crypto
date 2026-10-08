import Foundation

/// A path plus query items, relative to the API's base URL.
public struct Endpoint: Equatable, Sendable {
    public let path: String
    public let queryItems: [URLQueryItem]

    public init(path: String, queryItems: [URLQueryItem] = []) {
        self.path = path
        self.queryItems = queryItems
    }
}

/// Builds requests, sends them and decodes JSON, turning failures into `NetworkError`.
public struct APIClient: Sendable {
    private let baseURL: URL
    private let http: HTTPClient
    private let headers: [String: String]
    private let timeout: TimeInterval
    private let keyDecodingStrategy: JSONDecoder.KeyDecodingStrategy

    public init(
        baseURL: URL,
        http: HTTPClient = URLSessionHTTPClient(),
        headers: [String: String] = [:],
        timeout: TimeInterval = 15,
        keyDecodingStrategy: JSONDecoder.KeyDecodingStrategy = .convertFromSnakeCase
    ) {
        self.baseURL = baseURL
        self.http = http
        self.headers = headers
        self.timeout = timeout
        self.keyDecodingStrategy = keyDecodingStrategy
    }

    public func request(for endpoint: Endpoint) -> URLRequest {
        var components = URLComponents(
            url: baseURL.appendingPathComponent(endpoint.path),
            resolvingAgainstBaseURL: false
        )!
        if !endpoint.queryItems.isEmpty {
            components.queryItems = endpoint.queryItems
        }
        var request = URLRequest(url: components.url!, timeoutInterval: timeout)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        for (field, value) in headers {
            request.setValue(value, forHTTPHeaderField: field)
        }
        return request
    }

    /// Decodes JSON (snake_case → camelCase by default; pass `.useDefaultKeys`
    /// to the initializer when the response types declare their own `CodingKeys`).
    public func get<Response: Decodable>(_ endpoint: Endpoint, as type: Response.Type = Response.self) async throws -> Response {
        let result: (Data, HTTPURLResponse)
        do {
            result = try await http.data(for: request(for: endpoint))
        } catch let error as URLError where Self.offlineCodes.contains(error.code) {
            throw NetworkError.offline
        } catch let error as URLError where error.code == .cancelled {
            throw CancellationError() // e.g. a search that was superseded by newer typing
        } catch is CancellationError {
            throw CancellationError()
        } catch let error as NetworkError {
            throw error
        } catch {
            throw NetworkError.invalidResponse
        }

        let (data, response) = result

        switch response.statusCode {
        case 200..<300:
            break
        case 429:
            let retryAfter = response.value(forHTTPHeaderField: "Retry-After").flatMap { TimeInterval($0) }
            throw NetworkError.rateLimited(retryAfter: retryAfter)
        default:
            throw NetworkError.status(response.statusCode)
        }

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = keyDecodingStrategy
        do {
            return try decoder.decode(Response.self, from: data)
        } catch {
            throw NetworkError.decoding(String(describing: error))
        }
    }

    private static let offlineCodes: [URLError.Code] = [
        .notConnectedToInternet, .networkConnectionLost, .timedOut,
        .cannotFindHost, .cannotConnectToHost, .dataNotAllowed,
    ]
}
