import Foundation
import Observation

protocol ConnectionTesting: Sendable {
    func test(
        configuration: ServerConfiguration,
        credential: StoredCredential
    ) async throws -> String
}

struct LiveConnectionTester: ConnectionTesting {
    func test(
        configuration: ServerConfiguration,
        credential: StoredCredential
    ) async throws -> String {
        let anonymousAPI = URLSessionMemexAPI(
            configuration: configuration,
            credential: nil
        )
        try await anonymousAPI.health()

        let authorizedAPI = URLSessionMemexAPI(
            configuration: configuration,
            credential: credential
        )
        let notes = try await authorizedAPI.notes(limit: 1, tag: nil, kind: nil)
        return notes.isEmpty
            ? "Connected and authorized. No notes captured yet."
            : "Connected and authorized."
    }
}

enum ConnectionTestState: Equatable {
    case idle
    case testing
    case success(String)
    case failure(String)
}

@MainActor
@Observable
final class SettingsStore {
    var serverURL = ""
    var keyInput = ""
    private(set) var hasStoredKey = false
    private(set) var state: ConnectionTestState = .idle

    @ObservationIgnored private let connectionTester: any ConnectionTesting

    init(connectionTester: any ConnectionTesting = LiveConnectionTester()) {
        self.connectionTester = connectionTester
    }

    func load(from environment: AppEnvironment) {
        serverURL = environment.configuration?.displayString ?? serverURL
        hasStoredKey = environment.credential != nil
    }

    @discardableResult
    func saveAndTest(environment: AppEnvironment) async -> Bool {
        guard let configuration = ServerConfiguration(rawValue: serverURL) else {
            state = .failure(APIError.invalidServerURL.localizedDescription)
            return false
        }

        let enteredKey = keyInput.trimmingCharacters(in: .whitespacesAndNewlines)
        let candidateCredential: StoredCredential?
        if !enteredKey.isEmpty {
            candidateCredential = StoredCredential(token: enteredKey, origin: configuration.origin)
        } else if let existing = environment.credential,
                  existing.origin == configuration.origin {
            candidateCredential = existing
        } else {
            candidateCredential = nil
        }

        guard let candidateCredential else {
            state = .failure("Add the device key for this server.")
            return false
        }

        state = .testing
        do {
            let message = try await connectionTester.test(
                configuration: configuration,
                credential: candidateCredential
            )
            try await environment.install(
                configuration: configuration,
                credential: candidateCredential
            )
            keyInput = ""
            hasStoredKey = true
            state = .success(message)
            return true
        } catch is CancellationError {
            state = .idle
            return false
        } catch {
            state = .failure(error.localizedDescription)
            return false
        }
    }

    func clearKey(environment: AppEnvironment) async {
        do {
            try await environment.clearCredential()
            hasStoredKey = false
            keyInput = ""
            state = .success("Device key cleared.")
        } catch {
            state = .failure(error.localizedDescription)
        }
    }
}
