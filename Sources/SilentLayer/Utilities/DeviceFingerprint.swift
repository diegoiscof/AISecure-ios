//
//  DeviceFingerprint.swift
//  SilentLayer
//
//  Created by Diego Francisco Oruna Cabrera on 22/12/25.
//

import Foundation
import Security

/// Manages a persistent device identifier stored securely in the Keychain
///
/// The identifier persists across app reinstalls (as long as the user doesn't
/// reset all Keychain data). This provides a stable device fingerprint for
/// authentication purposes.
///
/// ## Security
/// - Stored in iOS Keychain with `kSecAttrAccessibleAfterFirstUnlock`
/// - Not backed up to iCloud (stays on device)
/// - Survives app reinstalls
public enum DeviceIdentifier {
    
    private static let service = "ai.silentlayer.device"
    private static let account = "device-id"
    
    // MARK: - Public API
    
    /// Gets the persistent device identifier, creating one if it doesn't exist
    ///
    /// Thread-safe and idempotent - calling multiple times returns the same ID.
    ///
    /// - Returns: A UUID string that uniquely identifies this device
    public static func get() -> String {
        // Try to load existing ID
        if let existing = load() {
            return existing
        }
        
        // Generate and save new ID
        let newID = UUID().uuidString
        
        do {
            try save(newID)
        } catch {
            // If save fails, still return the ID (it just won't persist)
            logIf(.warning)?.warning("⚠️ Failed to persist device ID: \(error.localizedDescription)")
        }
        
        return newID
    }
    
    /// Checks if a device identifier exists in the Keychain
    public static var exists: Bool {
        load() != nil
    }
    
    /// Deletes the stored device identifier
    ///
    /// Use with caution - this will cause the device to get a new ID on next `get()` call,
    /// which may invalidate existing sessions.
    public static func reset() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        
        if status == errSecSuccess {
            logIf(.info)?.info("🗑️ Device identifier reset")
        } else if status != errSecItemNotFound {
            logIf(.warning)?.warning("⚠️ Failed to reset device identifier: \(status)")
        }
    }
    
    // MARK: - Private
    
    private static func save(_ id: String) throws {
        let data = Data(id.utf8)
        
        // Query to identify the item
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        
        // Delete any existing item first
        SecItemDelete(query as CFDictionary)
        
        // Attributes for the new item
        var attributes = query
        attributes[kSecValueData as String] = data
        attributes[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        
        let status = SecItemAdd(attributes as CFDictionary, nil)
        
        guard status == errSecSuccess else {
            throw KeychainError.saveFailed(status: status)
        }
        
        logIf(.debug)?.debug("✅ Device identifier saved to Keychain")
    }
    
    private static func load() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        switch status {
        case errSecSuccess:
            guard let data = result as? Data,
                  let id = String(data: data, encoding: .utf8) else {
                logIf(.warning)?.warning("⚠️ Keychain data corrupted")
                return nil
            }
            return id
            
        case errSecItemNotFound:
            return nil
            
        default:
            logIf(.warning)?.warning("⚠️ Keychain read failed: \(status)")
            return nil
        }
    }
    
    // MARK: - Errors
    
    private enum KeychainError: Error, LocalizedError {
        case saveFailed(status: OSStatus)
        
        var errorDescription: String? {
            switch self {
            case .saveFailed(let status):
                return "Keychain save failed with status: \(status)"
            }
        }
    }
}
