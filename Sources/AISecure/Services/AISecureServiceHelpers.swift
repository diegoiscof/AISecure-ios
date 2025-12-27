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
    
    // MARK: - Retry State Machine
    
    /// Represents the retry state for authentication failures.
    /// Since JWT and session are created together on the backend,
    /// we only need one retry attempt with fresh credentials.
    private enum RetryState {
        case initial
        case retriedWithFreshCredentials
        
        /// Advances the state and performs necessary invalidations.
        /// Returns `true` if a retry should be attempted, `false` if exhausted.
        @AISecureActor mutating func handleAuthFailure(
            authenticator: AISecureDeviceAuthenticator?,
            sessionManager: AISecureSessionManager,
            errorCode: String? = nil
        ) -> Bool {
            // Don't retry for certain error types
            if let code = errorCode {
                switch code {
                case "DEVICE_MISMATCH", "INVALID_SIGNATURE":
                    logIf(.error)?.error("❌ Auth error (\(code)) - not recoverable via retry")
                    return false
                default:
                    break
                }
            }
            
            switch self {
            case .initial:
                guard let authenticator = authenticator else {
                    logIf(.error)?.error("❌ No authenticator available for credential refresh")
                    return false
                }
                
                logIf(.info)?.info("⚠️ Auth failed (401), refreshing credentials...")
                
                // Invalidate both - they're coupled on the backend
                authenticator.invalidateJWT()
                sessionManager.invalidateSession()
                
                self = .retriedWithFreshCredentials
                return true
                
            case .retriedWithFreshCredentials:
                logIf(.error)?.error("❌ Auth failed after credential refresh - giving up")
                return false
            }
        }
        
        /// Whether credentials should be force-refreshed (skip cache)
        var shouldForceRefresh: Bool {
            self == .retriedWithFreshCredentials
        }
    }
    
    // MARK: - Public API
    
    /// Executes a request with automatic credential refresh on 401 errors.
    ///
    /// Flow:
    /// 1. Get JWT (cached or fresh)
    /// 2. Get session from JWT payload
    /// 3. Execute request
    /// 4. On 401: invalidate JWT + session, retry once with fresh credentials
    ///
    /// - Parameters:
    ///   - deviceAuthenticator: Handles JWT retrieval and refresh
    ///   - sessionManager: Manages session derived from JWT
    ///   - configuration: Service configuration
    ///   - makeRequest: Closure that builds and executes the actual request
    /// - Returns: Response data and URLResponse
    static func executeWithRetry<T: Sendable>(
        deviceAuthenticator: AISecureDeviceAuthenticator?,
        sessionManager: AISecureSessionManager,
        configuration: AISecureConfiguration,
        makeRequest: @Sendable (AISecureServiceConfig, AISecureSession) async throws -> (T, URLResponse)
    ) async throws -> (T, URLResponse) {
        var state = RetryState.initial
        
        while true {
            // 1. Resolve credentials (JWT → service config + session)
            let (service, session) = try await resolveCredentials(
                deviceAuthenticator: deviceAuthenticator,
                sessionManager: sessionManager,
                configuration: configuration,
                forceRefresh: state.shouldForceRefresh
            )
            
            // 2. Execute the request
            do {
                let (data, response) = try await makeRequest(service, session)
                
                // 3. Check for 401 in HTTP response
                if let http = response as? HTTPURLResponse, http.statusCode == 401 {
                    if state.handleAuthFailure(
                        authenticator: deviceAuthenticator,
                        sessionManager: sessionManager,
                        errorCode: extractErrorCode(from: data)
                    ) {
                        continue // Retry with fresh credentials
                    }
                    // Retries exhausted, throw the error
                    throw AISecureError.httpError(status: 401, body: "Authentication failed")
                }
                
                return (data, response)
                
            } catch let error as AISecureError {
                // 4. Check for 401 in thrown error (streaming path)
                if case .httpError(let status, let body) = error, status == 401 {
                    let errorCode = extractErrorCode(from: body)
                    
                    if state.handleAuthFailure(
                        authenticator: deviceAuthenticator,
                        sessionManager: sessionManager,
                        errorCode: errorCode
                    ) {
                        continue // Retry with fresh credentials
                    }
                }
                throw error
            }
        }
    }
    
    // MARK: - Response Validation
    
    /// Validates HTTP response and throws appropriate errors for non-2xx status codes.
    static func validateResponse(_ response: URLResponse, data: Data) throws {
        guard let http = response as? HTTPURLResponse else {
            throw AISecureError.invalidResponse
        }
        
        guard (200...299).contains(http.statusCode) else {
            let body = parseErrorBody(from: data)
            logIf(.error)?.error("HTTP \(http.statusCode): \(String(describing: body))")
            throw AISecureError.httpError(status: http.statusCode, body: body)
        }
    }
    
    // MARK: - Private Helpers
    
    /// Resolves service configuration and session from JWT.
    private static func resolveCredentials(
        deviceAuthenticator: AISecureDeviceAuthenticator?,
        sessionManager: AISecureSessionManager,
        configuration: AISecureConfiguration,
        forceRefresh: Bool
    ) async throws -> (AISecureServiceConfig, AISecureSession) {
        // Get JWT (this will refresh if invalidated or expired)
        guard let jwt = try await deviceAuthenticator?.getValidJWT() else {
            throw AISecureError.invalidConfiguration("JWT authentication required")
        }
        
        // Decode payload (throws if malformed)
        let payload = try jwt.decodePayload()
        
        // Build service config from JWT payload
        let service = try AISecureServiceConfig(
            provider: payload.provider,
            serviceURL: configuration.service.serviceURL,
            partialKey: payload.partialKey
        )
        
        // Get session from JWT payload (force refresh clears cache)
        let session = try await sessionManager.getValidSession(
            forceRefresh: forceRefresh,
            jwtPayload: payload
        )
        
        return (service, session)
    }
    
    /// Extracts error code from response body if available.
    /// Expected format: { "code": "SESSION_EXPIRED", "message": "..." }
    private static func extractErrorCode(from body: Any?) -> String? {
        if let data = body as? Data,
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let code = json["code"] as? String {
            return code
        }
        
        if let dict = body as? [String: Any],
           let code = dict["code"] as? String {
            return code
        }
        
        if let str = body as? String,
           let data = str.data(using: .utf8),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let code = json["code"] as? String {
            return code
        }
        
        return nil
    }
    
    /// Parses error body from response data.
    private static func parseErrorBody(from data: Data) -> Any {
        if let json = try? JSONSerialization.jsonObject(with: data) {
            return json
        }
        return [
            "error": "Failed to parse error response",
            "raw": String(data: data, encoding: .utf8) ?? "Unable to decode data"
        ]
    }
}
