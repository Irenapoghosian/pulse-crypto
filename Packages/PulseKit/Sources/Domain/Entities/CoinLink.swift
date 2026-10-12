import Foundation

/// The `pulse://coin/<id>?symbol=…&name=…` link that opens a coin's screen.
///
/// Widgets build it and the app parses it. Carrying the symbol and name lets the
/// coin screen show its header right away, before any market data has loaded.
public enum CoinLink {
    public static let scheme = "pulse"
    private static let host = "coin"

    public static func url(for coin: CoinIdentity) -> URL {
        var components = URLComponents()
        components.scheme = scheme
        components.host = host
        components.path = "/" + coin.id
        var items = [
            encodedItem("symbol", coin.symbol),
            encodedItem("name", coin.name),
        ]
        if let image = coin.imageURL {
            items.append(encodedItem("image", image.absoluteString))
        }
        // `queryItems` would leave `&`, `=` and `+` unescaped and break names like "A & B".
        components.percentEncodedQueryItems = items
        // Every part above is valid, so this never falls back in practice.
        return components.url ?? URL(string: "\(scheme)://\(host)")!
    }

    /// The coin a link points to, or `nil` if it isn't a coin link.
    public static func identity(from url: URL) -> CoinIdentity? {
        guard
            url.scheme == scheme,
            url.host == host,
            let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        else { return nil }

        let id = components.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard !id.isEmpty, !id.contains("/") else { return nil }

        let items = components.queryItems ?? []
        func value(_ name: String) -> String? {
            items.first { $0.name == name }?.value.flatMap { $0.isEmpty ? nil : $0 }
        }
        return CoinIdentity(
            id: id,
            symbol: value("symbol") ?? id.uppercased(),
            name: value("name") ?? id.capitalized,
            imageURL: value("image").flatMap(URL.init(string:))
        )
    }

    private static let valueAllowed = CharacterSet.urlQueryAllowed.subtracting(CharacterSet(charactersIn: "&=+?/"))

    private static func encodedItem(_ name: String, _ value: String) -> URLQueryItem {
        URLQueryItem(name: name, value: value.addingPercentEncoding(withAllowedCharacters: valueAllowed) ?? "")
    }
}
