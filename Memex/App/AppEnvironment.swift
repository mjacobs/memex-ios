import Foundation
import Observation

@MainActor
@Observable
final class AppEnvironment {
    private(set) var configuration: ServerConfiguration?
    private(set) var credential: StoredCredential?
    private(set) var api: (any MemexAPI)?
    private(set) var isRestoring = true
    private(set) var connectionVersion = 0

    @ObservationIgnored private let preferences: any PreferencesStoring
    @ObservationIgnored private let credentialStore: any CredentialStoring

    init(
        preferences: any PreferencesStoring,
        credentialStore: any CredentialStoring
    ) {
        self.preferences = preferences
        self.credentialStore = credentialStore
    }

    static func live() -> AppEnvironment {
        AppEnvironment(
            preferences: UserDefaultsPreferences(),
            credentialStore: KeychainCredentialStore()
        )
    }

    static func initial() -> AppEnvironment {
        #if DEBUG
        if ProcessInfo.processInfo.environment["MEMEX_PREVIEW_MODE"] == "1" {
            return preview()
        }
        #endif
        return live()
    }

    static func preview(connected: Bool = true) -> AppEnvironment {
        let environment = AppEnvironment(
            preferences: MemoryPreferencesStore(),
            credentialStore: MemoryCredentialStore()
        )
        environment.isRestoring = false
        guard connected,
              let configuration = ServerConfiguration(rawValue: "https://memex.example.com")
        else {
            return environment
        }
        let credential = StoredCredential(token: "preview", origin: configuration.origin)
        environment.configuration = configuration
        environment.credential = credential
        environment.api = PreviewMemexAPI()
        return environment
    }

    var isReady: Bool {
        configuration != nil && credential != nil && api != nil
    }

    func restoreConnection() async {
        defer { isRestoring = false }
        guard let rawURL = preferences.loadServerURL(),
              let configuration = ServerConfiguration(rawValue: rawURL)
        else {
            return
        }

        do {
            let credential = try await credentialStore.load()
            self.configuration = configuration
            guard let credential,
                  credential.origin == configuration.origin
            else {
                return
            }
            self.credential = credential
            api = URLSessionMemexAPI(configuration: configuration, credential: credential)
        } catch {
            self.credential = nil
            api = nil
        }
    }

    func install(
        configuration: ServerConfiguration,
        credential: StoredCredential
    ) async throws {
        try await credentialStore.save(credential)
        preferences.saveServerURL(configuration.displayString)
        self.configuration = configuration
        self.credential = credential
        api = URLSessionMemexAPI(configuration: configuration, credential: credential)
        connectionVersion += 1
        isRestoring = false
    }

    func clearCredential() async throws {
        try await credentialStore.clear()
        credential = nil
        api = nil
        connectionVersion += 1
    }
}
