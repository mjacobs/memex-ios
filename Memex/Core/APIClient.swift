import Foundation

protocol MemexAPI: Sendable {
    func health() async throws
    func notes(limit: Int, tag: String?, kind: String?) async throws -> [Note]
    func note(id: String) async throws -> Note
    func captureText(_ text: String) async throws -> CaptureResponse
    func captureAudio(_ data: Data, mimeType: String) async throws -> String
    func capture(id: String) async throws -> Capture
    func tasks(status: TaskStatus) async throws -> [MemexTask]
    func updateTask(id: String, status: TaskStatus) async throws -> MemexTask
}

enum APIError: LocalizedError, Equatable, Sendable {
    case invalidServerURL
    case missingCredentials
    case invalidResponse
    case transport(String)
    case server(code: String, message: String, status: Int)
    case decoding(String)

    var errorDescription: String? {
        switch self {
        case .invalidServerURL:
            "Enter a valid HTTPS Memex server URL."
        case .missingCredentials:
            "Add a device key in Settings."
        case .invalidResponse:
            "The server returned an invalid response."
        case .transport(let message):
            message
        case .server(_, let message, _):
            message
        case .decoding:
            "The server response did not match the Memex API."
        }
    }
}

final class OriginLockedSessionDelegate: NSObject, URLSessionTaskDelegate, @unchecked Sendable {
    let allowedOrigin: URLOrigin

    init(allowedOrigin: URLOrigin) {
        self.allowedOrigin = allowedOrigin
    }

    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        willPerformHTTPRedirection response: HTTPURLResponse,
        newRequest request: URLRequest,
        completionHandler: @escaping (URLRequest?) -> Void
    ) {
        guard let url = request.url,
              URLOrigin(url: url) == allowedOrigin
        else {
            completionHandler(nil)
            return
        }
        completionHandler(request)
    }
}

actor URLSessionMemexAPI: MemexAPI {
    private let configuration: ServerConfiguration
    private let credential: StoredCredential?
    private let session: URLSession
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(
        configuration: ServerConfiguration,
        credential: StoredCredential?,
        session: URLSession? = nil
    ) {
        self.configuration = configuration
        self.credential = credential
        if let session {
            self.session = session
        } else {
            let sessionConfiguration = URLSessionConfiguration.ephemeral
            sessionConfiguration.timeoutIntervalForRequest = 30
            sessionConfiguration.timeoutIntervalForResource = 60
            self.session = URLSession(
                configuration: sessionConfiguration,
                delegate: OriginLockedSessionDelegate(allowedOrigin: configuration.origin),
                delegateQueue: nil
            )
        }
        encoder = JSONEncoder()
        decoder = JSONDecoder()
    }

    func health() async throws {
        let response: HealthResponse = try await request(path: "health", authorized: false)
        guard response.ok else {
            throw APIError.invalidResponse
        }
    }

    func notes(limit: Int = 50, tag: String? = nil, kind: String? = nil) async throws -> [Note] {
        var query = [URLQueryItem(name: "limit", value: String(limit))]
        if let tag { query.append(URLQueryItem(name: "tag", value: tag)) }
        if let kind { query.append(URLQueryItem(name: "kind", value: kind)) }
        let response: NotesResponse = try await request(path: "api/v1/notes", query: query)
        return response.notes
    }

    func note(id: String) async throws -> Note {
        let response: NoteResponse = try await request(path: "api/v1/notes/\(id)")
        return response.note
    }

    func captureText(_ text: String) async throws -> CaptureResponse {
        try await request(
            path: "api/v1/capture",
            method: "POST",
            body: encoder.encode(TextCaptureRequest(text: text))
        )
    }

    func captureAudio(_ data: Data, mimeType: String = "audio/mp4") async throws -> String {
        let response: CaptureResponse = try await request(
            path: "api/v1/capture/audio",
            method: "POST",
            headers: ["Content-Type": mimeType, "X-Memex-Source": "ios"],
            body: data
        )
        guard let id = response.id else {
            throw APIError.invalidResponse
        }
        return id
    }

    func capture(id: String) async throws -> Capture {
        let response: CaptureResponse = try await request(path: "api/v1/captures/\(id)")
        guard let capture = response.capture else {
            throw APIError.invalidResponse
        }
        return capture
    }

    func tasks(status: TaskStatus) async throws -> [MemexTask] {
        let response: TasksResponse = try await request(
            path: "api/v1/tasks",
            query: [URLQueryItem(name: "status", value: status.rawValue)]
        )
        return response.tasks
    }

    func updateTask(id: String, status: TaskStatus) async throws -> MemexTask {
        let response: TaskResponse = try await request(
            path: "api/v1/tasks/\(id)",
            method: "PATCH",
            body: encoder.encode(PatchTaskRequest(status: status))
        )
        return response.task
    }

    private func request<Response: Decodable & Sendable>(
        path: String,
        method: String = "GET",
        query: [URLQueryItem] = [],
        headers: [String: String] = [:],
        body: Data? = nil,
        authorized: Bool = true
    ) async throws -> Response {
        let url = try configuration.url(path: path, queryItems: query)
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.httpBody = body
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if body != nil && headers["Content-Type"] == nil {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        for (name, value) in headers {
            request.setValue(value, forHTTPHeaderField: name)
        }

        if authorized {
            guard let credential,
                  credential.origin == configuration.origin
            else {
                throw APIError.missingCredentials
            }
            request.setValue("Bearer \(credential.token)", forHTTPHeaderField: "Authorization")
        }

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            throw APIError.transport(error.localizedDescription)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            if let envelope = try? decoder.decode(APIErrorEnvelope.self, from: data) {
                throw APIError.server(
                    code: envelope.error.code,
                    message: envelope.error.message,
                    status: httpResponse.statusCode
                )
            }
            throw APIError.server(
                code: "http_\(httpResponse.statusCode)",
                message: HTTPURLResponse.localizedString(forStatusCode: httpResponse.statusCode),
                status: httpResponse.statusCode
            )
        }

        do {
            return try decoder.decode(Response.self, from: data)
        } catch {
            throw APIError.decoding(error.localizedDescription)
        }
    }
}
