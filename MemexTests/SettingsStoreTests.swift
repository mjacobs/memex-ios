import XCTest
@testable import Memex

@MainActor
final class SettingsStoreTests: XCTestCase {
    func testSuccessfulConnectionInstallsConfigurationAndCredential() async {
        let preferences = MemoryPreferencesStore()
        let credentials = MemoryCredentialStore()
        let environment = AppEnvironment(
            preferences: preferences,
            credentialStore: credentials
        )
        let store = SettingsStore(connectionTester: StubConnectionTester(message: "Connected"))
        store.serverURL = "https://memex.example.com"
        store.keyInput = "secret"

        let result = await store.saveAndTest(environment: environment)

        XCTAssertTrue(result)
        XCTAssertTrue(environment.isReady)
        XCTAssertEqual(preferences.loadServerURL(), "https://memex.example.com")
        XCTAssertEqual(environment.credential?.token, "secret")
        XCTAssertEqual(store.state, .success("Connected"))
    }

    func testFailedConnectionKeepsExistingConnection() async throws {
        let existingConfiguration = try XCTUnwrap(ServerConfiguration(rawValue: "https://old.example.com"))
        let existingCredential = StoredCredential(token: "old-key", origin: existingConfiguration.origin)
        let preferences = MemoryPreferencesStore(value: existingConfiguration.displayString)
        let credentials = MemoryCredentialStore(credential: existingCredential)
        let environment = AppEnvironment(preferences: preferences, credentialStore: credentials)
        await environment.restoreConnection()
        let store = SettingsStore(connectionTester: StubConnectionTester(shouldFail: true))
        store.load(from: environment)
        store.serverURL = "https://new.example.com"
        store.keyInput = "new-key"

        let result = await store.saveAndTest(environment: environment)

        XCTAssertFalse(result)
        XCTAssertEqual(environment.configuration, existingConfiguration)
        XCTAssertEqual(environment.credential, existingCredential)
        XCTAssertEqual(preferences.loadServerURL(), existingConfiguration.displayString)
    }
}

private struct StubConnectionTester: ConnectionTesting {
    var message = "Connected"
    var shouldFail = false

    func test(
        configuration: ServerConfiguration,
        credential: StoredCredential
    ) async throws -> String {
        if shouldFail { throw TestFailure.expected }
        return message
    }
}
