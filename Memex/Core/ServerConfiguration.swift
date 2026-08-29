import Foundation

struct URLOrigin: Codable, Equatable, Sendable {
    let scheme: String
    let host: String
    let port: Int?

    init?(url: URL) {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let scheme = components.scheme?.lowercased(),
              let host = components.host?.lowercased()
        else {
            return nil
        }
        self.scheme = scheme
        self.host = host
        if (scheme == "https" && components.port == 443) ||
            (scheme == "http" && components.port == 80) {
            port = nil
        } else {
            port = components.port
        }
    }
}

struct ServerConfiguration: Codable, Equatable, Sendable {
    let baseURL: URL
    let origin: URLOrigin

    init?(rawValue: String) {
        let rawValue = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard var components = URLComponents(string: rawValue),
              let scheme = components.scheme?.lowercased(),
              let host = components.host?.lowercased(),
              ["https", "http"].contains(scheme),
              components.user == nil,
              components.password == nil,
              components.query == nil,
              components.fragment == nil
        else {
            return nil
        }

        let localHosts = ["localhost", "127.0.0.1", "::1"]
        guard scheme == "https" || localHosts.contains(host) else {
            return nil
        }

        components.scheme = scheme
        components.host = host
        if (scheme == "https" && components.port == 443) ||
            (scheme == "http" && components.port == 80) {
            components.port = nil
        }
        components.path = components.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        if !components.path.isEmpty {
            components.path = "/" + components.path + "/"
        } else {
            components.path = "/"
        }

        guard let normalizedURL = components.url,
              let origin = URLOrigin(url: normalizedURL)
        else {
            return nil
        }
        baseURL = normalizedURL
        self.origin = origin
    }

    var displayString: String {
        var value = baseURL.absoluteString
        if baseURL.path == "/" {
            value.removeLast()
        }
        return value
    }

    func url(path: String, queryItems: [URLQueryItem] = []) throws -> URL {
        let relativePath = path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let url = baseURL.appending(path: relativePath)
        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            throw APIError.invalidServerURL
        }
        if !queryItems.isEmpty {
            components.queryItems = queryItems
        }
        guard let result = components.url,
              URLOrigin(url: result) == origin
        else {
            throw APIError.invalidServerURL
        }
        return result
    }
}
