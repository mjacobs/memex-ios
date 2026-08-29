import Foundation
import Security

struct StoredCredential: Codable, Equatable, Sendable {
    let token: String
    let origin: URLOrigin
}

protocol CredentialStoring: Sendable {
    func load() async throws -> StoredCredential?
    func save(_ credential: StoredCredential) async throws
    func clear() async throws
}

protocol PreferencesStoring: Sendable {
    func loadServerURL() -> String?
    func saveServerURL(_ value: String?)
}

final class UserDefaultsPreferences: PreferencesStoring, @unchecked Sendable {
    private let defaults: UserDefaults
    private let key = "memex.server-url"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func loadServerURL() -> String? {
        defaults.string(forKey: key)
    }

    func saveServerURL(_ value: String?) {
        if let value {
            defaults.set(value, forKey: key)
        } else {
            defaults.removeObject(forKey: key)
        }
    }
}

enum CredentialStoreError: LocalizedError, Equatable {
    case encodingFailed
    case decodingFailed
    case keychain(OSStatus)

    var errorDescription: String? {
        switch self {
        case .encodingFailed, .decodingFailed:
            "The saved device key could not be read."
        case .keychain:
            "The device key could not be accessed in Keychain."
        }
    }
}

actor KeychainCredentialStore: CredentialStoring {
    private let service: String
    private let account = "memex.device-key"

    init(service: String = "com.memex.ios.credentials") {
        self.service = service
    }

    func load() throws -> StoredCredential? {
        var query = baseQuery
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound {
            return nil
        }
        guard status == errSecSuccess else {
            throw CredentialStoreError.keychain(status)
        }
        guard let data = result as? Data,
              let credential = try? JSONDecoder().decode(StoredCredential.self, from: data)
        else {
            throw CredentialStoreError.decodingFailed
        }
        return credential
    }

    func save(_ credential: StoredCredential) throws {
        guard let data = try? JSONEncoder().encode(credential) else {
            throw CredentialStoreError.encodingFailed
        }

        SecItemDelete(baseQuery as CFDictionary)
        var query = baseQuery
        query[kSecValueData as String] = data
        query[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw CredentialStoreError.keychain(status)
        }
    }

    func clear() throws {
        let status = SecItemDelete(baseQuery as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw CredentialStoreError.keychain(status)
        }
    }

    private var baseQuery: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
    }
}

actor MemoryCredentialStore: CredentialStoring {
    private var credential: StoredCredential?

    init(credential: StoredCredential? = nil) {
        self.credential = credential
    }

    func load() -> StoredCredential? {
        credential
    }

    func save(_ credential: StoredCredential) {
        self.credential = credential
    }

    func clear() {
        credential = nil
    }
}

final class MemoryPreferencesStore: PreferencesStoring, @unchecked Sendable {
    private let lock = NSLock()
    private var value: String?

    init(value: String? = nil) {
        self.value = value
    }

    func loadServerURL() -> String? {
        lock.withLock { value }
    }

    func saveServerURL(_ value: String?) {
        lock.withLock { self.value = value }
    }
}
