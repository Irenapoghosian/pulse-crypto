import XCTest
@testable import Networking

final class APIClientTests: XCTestCase {

    private struct Payload: Decodable, Equatable {
        let currentPrice: Double
    }

    private let base = URL(string: "https://api.example.com/v3")!

    func testBuildsURLWithPathQueryAndHeaders() {
        let client = APIClient(baseURL: base, http: StubHTTPClient(), headers: ["x-key": "secret"])

        let request = client.request(for: Endpoint(
            path: "coins/markets",
            queryItems: [URLQueryItem(name: "vs_currency", value: "usd")]
        ))

        XCTAssertEqual(request.url?.absoluteString, "https://api.example.com/v3/coins/markets?vs_currency=usd")
        XCTAssertEqual(request.value(forHTTPHeaderField: "x-key"), "secret")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Accept"), "application/json")
    }

    func testDecodesSnakeCaseJSON() async throws {
        let http = StubHTTPClient(status: 200, body: #"{"current_price": 42.5}"#)
        let client = APIClient(baseURL: base, http: http)

        let payload: Payload = try await client.get(Endpoint(path: "x"))

        XCTAssertEqual(payload, Payload(currentPrice: 42.5))
    }

    func testRateLimitIncludesRetryAfter() async {
        let http = StubHTTPClient(status: 429, headers: ["Retry-After": "30"])
        await assertThrows(NetworkError.rateLimited(retryAfter: 30), using: http)
    }

    func testServerErrorsCarryTheStatus() async {
        await assertThrows(NetworkError.status(503), using: StubHTTPClient(status: 503))
    }

    func testNoConnectionBecomesOffline() async {
        await assertThrows(.offline, using: StubHTTPClient(error: URLError(.notConnectedToInternet)))
    }

    func testCancelledRequestBecomesCancellationError() async {
        let client = APIClient(baseURL: base, http: StubHTTPClient(error: URLError(.cancelled)))
        do {
            let _: Payload = try await client.get(Endpoint(path: "x"))
            XCTFail("Expected an error")
        } catch {
            XCTAssertTrue(error is CancellationError)
        }
    }

    func testMalformedJSONIsADecodingError() async {
        let client = APIClient(baseURL: base, http: StubHTTPClient(status: 200, body: #"{"oops": true}"#))
        do {
            let _: Payload = try await client.get(Endpoint(path: "x"))
            XCTFail("Expected an error")
        } catch {
            guard case .decoding? = error as? NetworkError else {
                return XCTFail("Unexpected error \(error)")
            }
        }
    }

    // MARK: Helpers

    private func assertThrows(_ expected: NetworkError, using http: HTTPClient, line: UInt = #line) async {
        let client = APIClient(baseURL: base, http: http)
        do {
            let _: Payload = try await client.get(Endpoint(path: "x"))
            XCTFail("Expected \(expected)", line: line)
        } catch {
            XCTAssertEqual(error as? NetworkError, expected, line: line)
        }
    }
}

/// Returns a canned response (or error) for every request.
struct StubHTTPClient: HTTPClient {
    var status = 200
    var body = "{}"
    var headers: [String: String] = [:]
    var error: Error?

    func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        if let error { throw error }
        let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: headers)!
        return (Data(body.utf8), response)
    }
}
