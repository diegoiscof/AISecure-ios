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

    /// Get valid session from JWT payload
    /// NOTE: Session is now embedded in JWT, no separate backend call needed
    public func getValidSession(
        forceRefresh: Bool = false,
        jwtPayload: DeviceJWT.Payload
    ) async throws -> AISecureSession {
        // Force refresh skips cache check
        if !forceRefresh {
            // Check cached session first
            if let cached = cachedSession, !cached.isExpired {
                return cached
            }

            // Check storage
            if let stored = try? storage.loadSession(for: configuration.service.serviceURL),
               !stored.isExpired {
                cachedSession = stored
                return stored
            }
        }

        // Create session from JWT payload (no backend call!)
        let session = createSessionFromJWT(jwtPayload)
        cachedSession = session
        try? storage.saveSession(session, for: configuration.service.serviceURL)
        return session
    }

    /// Invalidate the current session (called when server returns 401)
    public func invalidateSession() {
        cachedSession = nil
        storage.deleteSession(for: configuration.service.serviceURL)
    }

    /// Create session from JWT payload (no backend call)
    /// Backend already created the session in /auth/device
    private func createSessionFromJWT(_ payload: DeviceJWT.Payload) -> AISecureSession {
        return AISecureSession(
            sessionToken: payload.sessionToken,
            expiresAt: payload.exp * 1000, // Convert seconds to milliseconds
            provider: payload.provider,
            serviceURL: configuration.service.serviceURL
        )
    }
}
