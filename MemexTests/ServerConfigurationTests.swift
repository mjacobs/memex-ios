import XCTest
@testable import Memex

final class ServerConfigurationTests: XCTestCase {}

extension ServerConfigurationTests {
    func testNormalizesHTTPSOriginAndBuildsAPIURL() throws {
        let configuration = try XCTUnwrap(
            ServerConfiguration(rawValue: " HTTPS://Memex.Example.com:443/base ")
        )

        XCTAssertEqual(configuration.displayString, "https://memex.example.com/base/")
        XCTAssertEqual(configuration.origin, URLOrigin(url: URL(string: "https://memex.example.com")!))
        XCTAssertEqual(
            try configuration.url(path: "/api/v1/notes").absoluteString,
            "https://memex.example.com/base/api/v1/notes"
        )
    }

    func testRejectsRemotePlainHTTPCredentialsAndQueries() {
        XCTAssertNil(ServerConfiguration(rawValue: "http://memex.example.com"))
        XCTAssertNil(ServerConfiguration(rawValue: "https://user:pass@memex.example.com"))
        XCTAssertNil(ServerConfiguration(rawValue: "https://memex.example.com?key=secret"))
    }

    func testAllowsPlainHTTPLocalhostForSimulatorDevelopment() {
        XCTAssertNotNil(ServerConfiguration(rawValue: "http://127.0.0.1:8080"))
    }
}
