//
//  AnthropicService.swift
//  AISecure
//
//  Created by Diego Francisco Oruna Cabrera on 22/12/25.
//

import Foundation

@AISecureActor public class AnthropicService: Sendable {
    private var configuration: AISecureConfiguration
    private let sessionManager: AISecureSessionManager
    private let requestBuilder: AISecureRequestBuilder
    private let urlSession: URLSession
    private let deviceAuthenticator: AISecureDeviceAuthenticator?

    nonisolated init(
        configuration: AISecureConfiguration,
        sessionManager: AISecureSessionManager,
        requestBuilder: AISecureRequestBuilder,
        urlSession: URLSession,
        deviceAuthenticator: AISecureDeviceAuthenticator? = nil
    ) {
        self.configuration = configuration
        self.sessionManager = sessionManager
        self.requestBuilder = requestBuilder
        self.urlSession = urlSession
        self.deviceAuthenticator = deviceAuthenticator
    }

    /// Get service config with credentials from JWT (if using JWT auth)
    private func getServiceConfig() async throws -> AISecureServiceConfig {
        guard let authenticator = deviceAuthenticator else {
            // No JWT auth, use existing config
            return configuration.service
        }

        // Get JWT and decode to extract partialKey
        let jwt = try await authenticator.getValidJWT()
        let payload = try jwt.decodePayload()

        // Create service config with partialKey from JWT
        return try AISecureServiceConfig(
            provider: payload.provider,
            serviceURL: configuration.service.serviceURL,
            partialKey: payload.partialKey
        )
    }

    /// Creates a message with Claude
    ///
    /// - Parameters:
    ///   - messages: Array of messages
    ///   - model: The model to use (default: "claude-sonnet-4-5-20250929")
    ///   - maxTokens: Maximum tokens to generate
    ///   - temperature: Sampling temperature between 0 and 1 (default: 0.7)
    /// - Returns: The message response
    public func createMessage(
        messages: [AnthropicMessage],
        model: String = "claude-sonnet-4-5-20250929",
        maxTokens: Int = 1024,
        temperature: Double = 0.7
    ) async throws -> AnthropicMessageResponse {
        guard !messages.isEmpty else {
            throw AISecureError.invalidConfiguration("Messages cannot be empty")
        }
        guard (0...1).contains(temperature) else {
            throw AISecureError.invalidConfiguration("Temperature must be between 0 and 1")
        }

        let body: [String: Any] = [
            "model": model,
            "messages": messages.map { ["role": $0.role, "content": $0.content] },
            "max_tokens": maxTokens,
            "temperature": temperature
        ]

        return try await jsonRequest(
            endpoint: "/v1/messages",
            body: body,
            response: AnthropicMessageResponse.self
        )
    }

    // MARK: - Private Methods

    private func jsonRequest<T: Decodable>(
        endpoint: String,
        body: [String: Any],
        response: T.Type
    ) async throws -> T {
        var retriedOnce = false
        var jwtRetried = false

        while true {
            // 🔑 Get credentials from JWT first (needed for session creation signature)
            let service = try await getServiceConfig()

            // Pass partialKey to session manager for signature verification
            let session = try await sessionManager.getValidSession(
                forceRefresh: retriedOnce,
                partialKey: service.partialKey
            )

            let bodyData = try JSONSerialization.data(withJSONObject: body)
            let request = requestBuilder.buildRequest(
                endpoint: endpoint,
                body: bodyData,
                session: session,
                service: service
            )

            logIf(.debug)?.debug("➡️ Request to \(endpoint)")

            let (data, urlResponse) = try await urlSession.data(for: request)

            // Check for 401 error - could be session expired OR JWT expired
            if let http = urlResponse as? HTTPURLResponse, http.statusCode == 401 {
                if !jwtRetried, let authenticator = deviceAuthenticator {
                    // Try refreshing JWT first
                    logIf(.info)?.info("⚠️ JWT may be expired, refreshing...")
                    authenticator.invalidateJWT()
                    jwtRetried = true
                    continue
                } else if !retriedOnce {
                    // Then try refreshing session
                    logIf(.info)?.info("⚠️ Session expired, refreshing and retrying...")
                    sessionManager.invalidateSession()
                    retriedOnce = true
                    jwtRetried = false
                    continue
                } else {
                    // Both JWT and session refresh failed
                    logIf(.error)?.error("❌ Authentication failed after retries")
                }
            }

            try validate(response: urlResponse, data: data)

            do {
                return try JSONDecoder().decode(T.self, from: data)
            } catch {
                throw AISecureError.decodingError(error)
            }
        }
    }

    private func validate(response: URLResponse, data: Data) throws {
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

            logIf(.error)?.error("HTTP \(http.statusCode) error: \(String(describing: body))")
            throw AISecureError.httpError(status: http.statusCode, body: body)
        }
    }
}
