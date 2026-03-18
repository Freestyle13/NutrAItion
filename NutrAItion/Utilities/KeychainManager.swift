//
//  KeychainManager.swift
//  NutrAItion
//

import Foundation
import Security

/// Secure storage for API keys and other secrets. Uses iOS Keychain (hardware-backed when available).
enum KeychainManager {
    private static var service: String {
        Bundle.main.bundleIdentifier ?? "com.nutraition.app"
    }

    /// Saves a string value for the given key. Overwrites if the key already exists.
    /// - Returns: `true` if save succeeded, `false` on any failure (no throw).
    static func save(key: String, value: String) -> Bool {
        guard let data = value.data(using: .utf8) else { return false }
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
        ]
        // Remove existing item so we can add (avoids errSecDuplicateItem)
        SecItemDelete(query as CFDictionary)
        let addQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
        ]
        let status = SecItemAdd(addQuery as CFDictionary, nil)
        return status == errSecSuccess
    }

    /// Loads the string value for the given key.
    /// - Returns: The value if found, `nil` on failure or missing key.
    static func load(key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    /// Deletes the item for the given key.
    /// - Returns: `true` if delete succeeded or item was already missing, `false` on unexpected error.
    static func delete(key: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
        ]
        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }
}

// MARK: - Key names for API credentials (use with KeychainManager.save/load/delete)

enum Keys {
    static let usdaApiKey = "usda_api_key"
    static let anthropicApiKey = "anthropic_api_key"
}
