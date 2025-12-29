//
//  DeviceJWT.swift
//  SilentLayer
//
//  Created by SilentLayer on 23/12/25.
//

import Foundation

/// JWT response from /auth/device endpoint
public struct DeviceJWT: Codable, Sendable {
    public let token: String
    public let expiresAt: Int

    /// Decoded JWT payload
    public struct Payload: Codable, Sendable {
        public let sessionToken: String
        public let partialKey: String
        public let serviceId: String
        public let provider: String
        public let deviceFingerprint: String
        public let projectId: String
        public let iat: Int // Issued at
        public let exp: Int // Expiry
    }

    /// Decode JWT payload (no verification, just Base64 decode)
    public func decodePayload() throws -> Payload {
        let segments = token.split(separator: ".")
        guard segments.count == 3 else {
            throw SilentLayerError.invalidConfiguration("Invalid JWT format")
        }

        // JWT payload is the second segment
        var base64 = String(segments[1])

        // Add padding if needed
        let remainder = base64.count % 4
        if remainder > 0 {
            base64 += String(repeating: "=", count: 4 - remainder)
        }

        guard let data = Data(base64Encoded: base64) else {
            throw SilentLayerError.invalidConfiguration("Invalid JWT Base64")
        }

        return try JSONDecoder().decode(Payload.self, from: data)
    }

    /// Check if JWT is expired
    public var isExpired: Bool {
        // expiresAt is in milliseconds, convert current time to ms for comparison
        return Date().timeIntervalSince1970 * 1000 > Double(expiresAt)
    }
}
