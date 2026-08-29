import XCTest
@testable import Memex

@MainActor
final class APIClientTests: XCTestCase {
    override func tearDown() {
        URLProtocolStub.handler = nil
        URLProtocolStub.lastRequest = nil
        super.tearDown()
    }

    func testNotesSendsOriginBoundBearerAndQuery() async throws {
        let configuration = try XCTUnwrap(ServerConfiguration(rawValue: "https://memex.example.com"))
        let credential = StoredCredential(token: "device-key", origin: configuration.origin)
        URLProtocolStub.handler = { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            )!
            return (response, Data(#"{"notes":[]}"#.utf8))
        }
        let api = makeAPI(configuration: configuration, credential: credential)

        let notes = try await api.notes(limit: 7, tag: "ios", kind: "capture")

        XCTAssertEqual(notes, [])
        let request = try XCTUnwrap(URLProtocolStub.lastRequest)
        XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer device-key")
        XCTAssertTrue(request.url?.absoluteString.contains("limit=7") == true)
        XCTAssertTrue(request.url?.absoluteString.contains("tag=ios") == true)
        XCTAssertTrue(request.url?.absoluteString.contains("kind=capture") == true)
    }

    func testHealthNeverSendsBearer() async throws {
        let configuration = try XCTUnwrap(ServerConfiguration(rawValue: "https://memex.example.com"))
        let credential = StoredCredential(token: "device-key", origin: configuration.origin)
        URLProtocolStub.handler = { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data(#"{"ok":true}"#.utf8))
        }
        let api = makeAPI(configuration: configuration, credential: credential)

        try await api.health()

        XCTAssertNil(URLProtocolStub.lastRequest?.value(forHTTPHeaderField: "Authorization"))
    }

    func testStructuredServerErrorIsPreserved() async throws {
        let configuration = try XCTUnwrap(ServerConfiguration(rawValue: "https://memex.example.com"))
        let credential = StoredCredential(token: "bad", origin: configuration.origin)
        URLProtocolStub.handler = { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 401, httpVersion: nil, headerFields: nil)!
            return (response, Data(#"{"error":{"code":"unauthorized","message":"Device key rejected"}}"#.utf8))
        }
        let api = makeAPI(configuration: configuration, credential: credential)

        do {
            _ = try await api.notes(limit: 1, tag: nil, kind: nil)
            XCTFail("Expected an API error")
        } catch let error as APIError {
            XCTAssertEqual(error, .server(code: "unauthorized", message: "Device key rejected", status: 401))
        }
    }

    private func makeAPI(
        configuration: ServerConfiguration,
        credential: StoredCredential
    ) -> URLSessionMemexAPI {
        let sessionConfiguration = URLSessionConfiguration.ephemeral
        sessionConfiguration.protocolClasses = [URLProtocolStub.self]
        return URLSessionMemexAPI(
            configuration: configuration,
            credential: credential,
            session: URLSession(configuration: sessionConfiguration)
        )
    }
}

private final class URLProtocolStub: URLProtocol, @unchecked Sendable {
    nonisolated(unsafe) static var handler: (@Sendable (URLRequest) throws -> (HTTPURLResponse, Data))?
    nonisolated(unsafe) static var lastRequest: URLRequest?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        Self.lastRequest = request
        guard let handler = Self.handler else {
            client?.urlProtocol(self, didFailWithError: TestFailure.expected)
            return
        }
        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}
