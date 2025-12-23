//
//  AISecureSessionManager.swift
//  AISecure
//
//  Created by Diego Francisco Oruna Cabrera on 22/12/25.
//

import Foundation
import CryptoKit

@AISecureActor public class AISecureSessionManager: Sendable {
    private let configuration: AISecureConfiguration
    private let storage: AISecureStorage
    private let urlSession: URLSession

    private var cachedSession: AISecureSession?

    nonisolated init(
        configuration: AISecureConfiguration,
        storage: AISecureStorage,
        urlSession: URLSession
    ) {
        self.configuration = configuration
        self.storage = storage
        self.urlSession = urlSession
    }

    public func getValidSession(forceRefresh: Bool = false, partialKey: String? = nil) async throws -> AISecureSession {
        // Force refresh skips cache check
        if !forceRefresh {
            // Check cached session first
            if let cached = cachedSession, !cached.isExpired {
                logIf(.debug)?.debug("✅ Using cached session")
                return cached
            }

            // Check storage
            if let stored = try? storage.loadSession(for: configuration.service.serviceURL),
               !stored.isExpired {
                logIf(.debug)?.debug("✅ Using stored session")
                cachedSession = stored
                return stored
            }
        } else {
            logIf(.debug)?.debug("🔄 Force refreshing session (previous session expired)")
        }

        // Create new session
        logIf(.debug)?.debug("🔄 Creating new session")
        let session = try await createSession(partialKey: partialKey)
        cachedSession = session
        try? storage.saveSession(session, for: configuration.service.serviceURL)
        return session
    }

    /// Invalidate the current session (called when server returns 401)
    public func invalidateSession() {
        cachedSession = nil
        storage.deleteSession(for: configuration.service.serviceURL)
    }

    private func createSession(partialKey: String? = nil) async throws -> AISecureSession {
        let endpoint = configuration.backendURL.appendingPathComponent("api/sessions")

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // Use provided partialKey (from JWT) or fall back to configuration
        let activePartialKey = partialKey ?? configuration.service.partialKey

        // 🔒 SECURITY: Sign session creation request with partialKey
        let timestamp = String(Int(Date().timeIntervalSince1970))
        let message = "\(timestamp):\(configuration.deviceFingerprint)"

        let key = SymmetricKey(data: Data(activePartialKey.utf8))
        let signature = HMAC<SHA256>.authenticationCode(
            for: Data(message.utf8),
            using: key
        )
        let signatureBase64 = Data(signature).base64EncodedString()

        request.setValue(signatureBase64, forHTTPHeaderField: "x-project-signature")
        request.setValue(timestamp, forHTTPHeaderField: "x-timestamp")

        // Generate rich device metadata
        let metadataString = await DeviceMetadata.generateMetadataString(
            partialKey: activePartialKey
        )
        let metadataBase64 = Data(metadataString.utf8).base64EncodedString()

        let body: [String: String] = [
            "serviceURL": configuration.service.serviceURL,
            "deviceFingerprint": configuration.deviceFingerprint,
            "metadata": metadataBase64
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        logIf(.debug)?.debug("➡️ Creating session for \(self.configuration.service.serviceURL)")

        let (data, response) = try await urlSession.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AISecureError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let errorBody = try? JSONSerialization.jsonObject(with: data)
            logIf(.error)?.error("Session creation failed: \(httpResponse.statusCode)")
            throw AISecureError.httpError(status: httpResponse.statusCode, body: errorBody ?? [:])
        }

        let session = try JSONDecoder().decode(AISecureSession.self, from: data)
        logIf(.debug)?.debug("✅ Session created, expires at \(session.expiresAt)")
        return session
    }
}
