//
//  SilentLayerStorage.swift
//  SilentLayer
//
//  Created by Diego Francisco Oruna Cabrera on 22/12/25.
//

import Foundation
import Security

public struct SilentLayerStorage: Sendable {
    private let serviceName = "com.aisecure.sessions"
    private let jwtServiceName = "com.aisecure.jwt"

    public init() {}

    public func saveSession(_ session: SilentLayerSession, for serviceURL: String) throws {
        let data = try JSONEncoder().encode(session)

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: serviceURL,
            kSecValueData as String: data
        ]

        // Delete existing item
        SecItemDelete(query as CFDictionary)

        // Add new item
        let status = SecItemAdd(query as CFDictionary, nil)

        guard status == errSecSuccess else {
            throw SilentLayerError.invalidConfiguration("Failed to save session to keychain")
        }
    }

    public func loadSession(for serviceURL: String) throws -> SilentLayerSession {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: serviceURL,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess,
              let data = result as? Data else {
            throw SilentLayerError.invalidConfiguration("No session found in keychain")
        }

        return try JSONDecoder().decode(SilentLayerSession.self, from: data)
    }

    public func deleteSession(for serviceURL: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: serviceURL
        ]

        SecItemDelete(query as CFDictionary)
    }

    // MARK: - JWT Storage

    public func saveJWT(_ jwt: DeviceJWT, for serviceURL: String) throws {
        let data = try JSONEncoder().encode(jwt)

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: jwtServiceName,
            kSecAttrAccount as String: serviceURL,
            kSecValueData as String: data
        ]

        // Delete existing item
        SecItemDelete(query as CFDictionary)

        // Add new item
        let status = SecItemAdd(query as CFDictionary, nil)

        guard status == errSecSuccess else {
            throw SilentLayerError.invalidConfiguration("Failed to save JWT to keychain")
        }
    }

    public func loadJWT(for serviceURL: String) throws -> DeviceJWT {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: jwtServiceName,
            kSecAttrAccount as String: serviceURL,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess,
              let data = result as? Data else {
            throw SilentLayerError.invalidConfiguration("No JWT found in keychain")
        }

        return try JSONDecoder().decode(DeviceJWT.self, from: data)
    }

    public func deleteJWT(for serviceURL: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: jwtServiceName,
            kSecAttrAccount as String: serviceURL
        ]

        SecItemDelete(query as CFDictionary)
    }
}
