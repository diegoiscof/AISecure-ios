//
//  AISecureServiceHelpers.swift
//  AISecure
//
//  Created by Diego Francisco Oruna Cabrera on 25/12/25.
//

import Foundation

/// Shared authentication and request execution logic for services
@AISecureActor
internal struct AISecureServiceHelpers {

    /// Executes a request with automatic JWT and session refresh on 401 errors
    static func executeWithRetry<T: Sendable>(
        deviceAuthenticator: AISecureDeviceAuthenticator?,
        sessionManager: AISecureSessionManager,
        configuration: AISecureConfiguration,
        makeRequest: @Sendable (AISecureServiceConfig, AISecureSession) async throws -> (T, URLResponse)
    ) async throws -> (T, URLResponse) {
        var retriedOnce = false
        var jwtRetried = false

        while true {
            // Get JWT and decode payload
            let jwt = try await deviceAuthenticator?.getValidJWT()
            let payload = try jwt?.decodePayload()

            // Get service config from JWT (or use configuration if no JWT auth)
            let service: AISecureServiceConfig
            if let payload = payload {
                service = try AISecureServiceConfig(
                    provider: payload.provider,
                    serviceURL: configuration.service.serviceURL,
                    partialKey: payload.partialKey
                )
            } else {
                service = configuration.service
            }

            // Get session from JWT payload
            let session: AISecureSession
            if let payload = payload {
                session = try await sessionManager.getValidSession(
                    forceRefresh: retriedOnce || jwtRetried,
                    jwtPayload: payload
                )
            } else {
                throw AISecureError.invalidConfiguration("JWT authentication required")
            }

            // Execute the request
            let (data, urlResponse) = try await makeRequest(service, session)

            // Check for 401 error - could be session expired OR JWT expired
            if let http = urlResponse as? HTTPURLResponse, http.statusCode == 401 {
                if !jwtRetried, let authenticator = deviceAuthenticator {
                    // Try refreshing JWT first
                    logIf(.info)?.info("⚠️ JWT expired, refreshing...")
                    authenticator.invalidateJWT()
                    jwtRetried = true
                    continue
                } else if !retriedOnce {
                    // Then try refreshing session
                    logIf(.info)?.info("⚠️ Session expired, refreshing...")
                    sessionManager.invalidateSession()
                    retriedOnce = true
                    jwtRetried = false
                    continue
                } else {
                    // Both JWT and session refresh failed
                    logIf(.error)?.error("❌ Auth failed after retries")
                }
            }

            return (data, urlResponse)
        }
    }

    /// Validates HTTP response and throws appropriate errors
    static func validateResponse(_ response: URLResponse, data: Data) throws {
        guard let http = response as? HTTPURLResponse else {
            throw AISecureError.invalidResponse
        }

        guard (200...299).contains(http.statusCode) else {
            let body: Any
            do {
                body = try JSONSerialization.jsonObject(with: data)
            } catch {
                body = [
                    "error": "Failed to parse error response",
                    "raw": String(data: data, encoding: .utf8) ?? "Unable to decode data"
                ]
            }

            logIf(.error)?.error("HTTP \(http.statusCode): \(String(describing: body))")
            throw AISecureError.httpError(status: http.statusCode, body: body)
        }
    }
}
