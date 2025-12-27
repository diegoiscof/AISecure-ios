//
//  GrokService.swift
//  AISecure
//
//  Created by Diego Francisco Oruna Cabrera on 26/12/25.
//

import Foundation

@AISecureActor public class GrokService: Sendable {
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

    /// Creates a chat completion request using Grok
    ///
    /// Grok uses OpenAI-compatible API format
    ///
    /// - Parameters:
    ///   - messages: Array of chat messages
    ///   - model: The model to use (default: "grok-4")
    ///   - temperature: Sampling temperature between 0 and 2 (default: 0.7)
    ///   - maxTokens: Maximum tokens to generate (optional)
    /// - Returns: The chat completion response (OpenAI-compatible format)
    public func chat(
        messages: [ChatMessage],
        model: String = "grok-4",
        temperature: Double = 0.7,
        maxTokens: Int? = nil
    ) async throws -> OpenAIChatResponse {
        guard !messages.isEmpty else {
            throw AISecureError.invalidConfiguration("Messages cannot be empty")
        }
        guard (0...2).contains(temperature) else {
            throw AISecureError.invalidConfiguration("Temperature must be between 0 and 2")
        }

        var body: [String: Any] = [
            "model": model,
            "messages": messages.map { ["role": $0.role, "content": $0.content] },
            "temperature": temperature
        ]

        if let maxTokens = maxTokens {
            body["max_tokens"] = maxTokens
        }

        return try await jsonRequest(
            endpoint: "/v1/chat/completions",
            body: body,
            response: OpenAIChatResponse.self
        )
    }

    /// Creates a chat completion with vision capabilities
    ///
    /// - Parameters:
    ///   - messages: Array of chat messages (can include image URLs)
    ///   - model: The model to use (default: "grok-4-1-fast-reasoning")
    ///   - temperature: Sampling temperature between 0 and 2 (default: 0.7)
    ///   - maxTokens: Maximum tokens to generate (optional)
    /// - Returns: The chat completion response
    public func chatWithVision(
        messages: [ChatMessage],
        model: String = "grok-4-1-fast-reasoning",
        temperature: Double = 0.7,
        maxTokens: Int? = nil
    ) async throws -> OpenAIChatResponse {
        guard !messages.isEmpty else {
            throw AISecureError.invalidConfiguration("Messages cannot be empty")
        }
        guard (0...2).contains(temperature) else {
            throw AISecureError.invalidConfiguration("Temperature must be between 0 and 2")
        }

        var body: [String: Any] = [
            "model": model,
            "messages": messages.map { ["role": $0.role, "content": $0.content] },
            "temperature": temperature
        ]

        if let maxTokens = maxTokens {
            body["max_tokens"] = maxTokens
        }

        return try await jsonRequest(
            endpoint: "/v1/chat/completions",
            body: body,
            response: OpenAIChatResponse.self
        )
    }

    /// Creates a streaming chat completion request using Grok
    ///
    /// Grok uses OpenAI-compatible streaming API format
    ///
    /// - Parameters:
    ///   - messages: Array of chat messages
    ///   - model: The model to use (default: "grok-4")
    ///   - temperature: Sampling temperature between 0 and 2 (default: 0.7)
    ///   - maxTokens: Maximum tokens to generate (optional)
    ///   - onChunk: Closure called for each streamed chunk with delta content
    /// - Throws: AISecureError if the request fails
    public func chatStream(
        messages: [ChatMessage],
        model: String = "grok-4",
        temperature: Double = 0.7,
        maxTokens: Int? = nil,
        onChunk: @escaping @Sendable (OpenAIChatStreamDelta) -> Void
    ) async throws {
        guard !messages.isEmpty else {
            throw AISecureError.invalidConfiguration("Messages cannot be empty")
        }
        guard (0...2).contains(temperature) else {
            throw AISecureError.invalidConfiguration("Temperature must be between 0 and 2")
        }

        var body: [String: Any] = [
            "model": model,
            "messages": messages.map { ["role": $0.role, "content": $0.content] },
            "temperature": temperature,
            "stream": true  // ⭐ Enable streaming
        ]

        if let maxTokens = maxTokens {
            body["max_tokens"] = maxTokens
        }

        try await streamRequest(
            endpoint: "/v1/chat/completions",
            body: body,
            onChunk: onChunk
        )
    }

    // MARK: - Private Methods

    private func jsonRequest<T: Decodable>(
        endpoint: String,
        body: [String: Any],
        response: T.Type
    ) async throws -> T {
        let bodyData = try JSONSerialization.data(withJSONObject: body)

        let (data, urlResponse) = try await AISecureServiceHelpers.executeWithRetry(
            deviceAuthenticator: deviceAuthenticator,
            sessionManager: sessionManager,
            configuration: configuration
        ) { service, session in
            let request = self.requestBuilder.buildRequest(
                endpoint: endpoint,
                body: bodyData,
                session: session,
                service: service
            )
            return try await self.urlSession.data(for: request)
        }

        try AISecureServiceHelpers.validateResponse(urlResponse, data: data)

        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw AISecureError.decodingError(error)
        }
    }

    private func streamRequest(
        endpoint: String,
        body: [String: Any],
        onChunk: @escaping @Sendable (OpenAIChatStreamDelta) -> Void
    ) async throws {
        let bodyData = try JSONSerialization.data(
            withJSONObject: body,
            options: [.sortedKeys]
        )

        try await AISecureServiceHelpers.executeWithRetry(
            deviceAuthenticator: deviceAuthenticator,
            sessionManager: sessionManager,
            configuration: configuration
        ) { service, session in
            let request = self.requestBuilder.buildRequest(
                endpoint: endpoint,
                body: bodyData,
                session: session,
                service: service
            )

            // Use URLSession.bytes for streaming
            let (bytes, response) = try await self.urlSession.bytes(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw AISecureError.invalidResponse
            }

            guard (200...299).contains(httpResponse.statusCode) else {
                // Don't consume the bytes iterator - just throw and let retry mechanism handle it
                throw AISecureError.httpError(status: httpResponse.statusCode, body: "HTTP \(httpResponse.statusCode)")
            }

            // Process Server-Sent Events (SSE)
            for try await line in bytes.lines {
                // SSE format: "data: {json}\n"
                if line.hasPrefix("data: ") {
                    let jsonString = String(line.dropFirst(6)) // Remove "data: " prefix

                    // Check for stream end
                    if jsonString == "[DONE]" {
                        logIf(.debug)?.debug("⚡ Grok stream complete")
                        break
                    }

                    // Parse JSON chunk
                    if let data = jsonString.data(using: .utf8) {
                        do {
                            let delta = try JSONDecoder().decode(OpenAIChatStreamDelta.self, from: data)
                            onChunk(delta)
                        } catch {
                            // Skip malformed chunks
                            logIf(.debug)?.debug("Failed to decode Grok chunk: \(error)")
                        }
                    }
                }
            }

            return (Data(), response) // Dummy return to satisfy executeWithRetry
        }
    }
}
