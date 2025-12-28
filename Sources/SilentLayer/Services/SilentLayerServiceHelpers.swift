//
//  SilentLayerServiceHelpers.swift
//  SilentLayer
//
//  Created by Diego Francisco Oruna Cabrera on 25/12/25.
//

import Foundation

@SilentLayerActor
internal struct SilentLayerServiceHelpers {
    
    // MARK: - Retry State
    
    private enum RetryState {
        case initial
        case retriedWithFreshCredentials
        
        @SilentLayerActor mutating func handleAuthFailure(
            authenticator: SilentLayerDeviceAuthenticator?,
            errorCode: String? = nil
        ) -> Bool {
            // Don't retry for certain error types
            if let code = errorCode {
                switch code {
                case "DEVICE_MISMATCH", "INVALID_SIGNATURE":
                    logIf(.error)?.error("❌ Auth error (\(code)) - not recoverable")
                    return false
                default:
                    break
                }
            }
            
            switch self {
            case .initial:
                guard let authenticator = authenticator else {
                    logIf(.error)?.error("❌ No authenticator for credential refresh")
                    return false
                }
                
                logIf(.info)?.info("⚠️ Auth failed (401), refreshing credentials...")
                authenticator.invalidateCredentials()
                
                self = .retriedWithFreshCredentials
                return true
                
            case .retriedWithFreshCredentials:
                logIf(.error)?.error("❌ Auth failed after refresh - giving up")
                return false
            }
        }
        
        var shouldForceRefresh: Bool {
            self == .retriedWithFreshCredentials
        }
    }
    
    // MARK: - Public API
    
    /// Execute request with automatic credential refresh on 401
    static func executeWithRetry<T: Sendable>(
        deviceAuthenticator: SilentLayerDeviceAuthenticator?,
        configuration: SilentLayerConfiguration,
        makeRequest: @Sendable (SilentLayerServiceConfig, SilentLayerSession) async throws -> (T, URLResponse)
    ) async throws -> (T, URLResponse) {
        var state = RetryState.initial
        
        while true {
            // Get credentials (cached or fresh)
            let credentials = try await resolveCredentials(
                deviceAuthenticator: deviceAuthenticator,
                forceRefresh: state.shouldForceRefresh
            )
            
            do {
                let (data, response) = try await makeRequest(credentials.service, credentials.session)
                
                // Check for 401 in HTTP response
                if let http = response as? HTTPURLResponse, http.statusCode == 401 {
                    let errorCode = extractErrorCode(from: data)
                    if state.handleAuthFailure(authenticator: deviceAuthenticator, errorCode: errorCode) {
                        continue
                    }
                    throw SilentLayerError.httpError(
                        status: 401,
                        body: HTTPErrorBody(code: errorCode, message: "Authentication failed", raw: nil)
                    )
                }
                
                return (data, response)
                
            } catch let error as SilentLayerError {
                // Check for 401 in thrown error (streaming path)
                if case .httpError(let status, let body) = error, status == 401 {
                    if state.handleAuthFailure(authenticator: deviceAuthenticator, errorCode: body.code) {
                        continue
                    }
                }
                throw error
            }
        }
    }
    
    // MARK: - Response Validation
    
    static func validateResponse(_ response: URLResponse, data: Data) throws {
        guard let http = response as? HTTPURLResponse else {
            throw SilentLayerError.invalidResponse
        }
        
        guard (200...299).contains(http.statusCode) else {
            let body = HTTPErrorBody(from: data)
            logIf(.error)?.error("HTTP \(http.statusCode): \(body.message ?? "Unknown error")")
            throw SilentLayerError.httpError(status: http.statusCode, body: body)
        }
    }
    
    // MARK: - Private Helpers
    
    private static func resolveCredentials(
        deviceAuthenticator: SilentLayerDeviceAuthenticator?,
        forceRefresh: Bool
    ) async throws -> SilentLayerCredentials {
        guard let authenticator = deviceAuthenticator else {
            throw SilentLayerError.invalidConfiguration("Device authenticator required")
        }
        return try await authenticator.getCredentials(forceRefresh: forceRefresh)
    }
    
    private static func extractErrorCode(from body: Any?) -> String? {
        if let data = body as? Data {
            return HTTPErrorBody(from: data).code
        }
        return nil
    }
}
