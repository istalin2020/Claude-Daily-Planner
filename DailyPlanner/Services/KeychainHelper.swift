import Foundation
import Security

/// Minimal Keychain wrapper for storing sensitive tokens (e.g. the Gmail
/// OAuth refresh token). Values are stored as generic passwords scoped to
/// this app and are never written to UserDefaults or iCloud backups.
enum KeychainHelper {

    private static let service = "com.dailyplanner.tokens"

    @discardableResult
    static func save(_ value: String, for key: String) -> Bool {
        guard let data = value.data(using: .utf8) else { return false }
        // Remove any existing item first so we always overwrite cleanly.
        delete(key)
        let query: [String: Any] = [
            kSecClass as String:            kSecClassGenericPassword,
            kSecAttrService as String:      service,
            kSecAttrAccount as String:      key,
            kSecValueData as String:        data,
            kSecAttrAccessible as String:   kSecAttrAccessibleAfterFirstUnlock
        ]
        return SecItemAdd(query as CFDictionary, nil) == errSecSuccess
    }

    static func read(_ key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String:            kSecClassGenericPassword,
            kSecAttrService as String:      service,
            kSecAttrAccount as String:      key,
            kSecReturnData as String:       true,
            kSecMatchLimit as String:       kSecMatchLimitOne
        ]
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data,
              let str  = String(data: data, encoding: .utf8) else { return nil }
        return str
    }

    @discardableResult
    static func delete(_ key: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String:        kSecClassGenericPassword,
            kSecAttrService as String:  service,
            kSecAttrAccount as String:  key
        ]
        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }
}
