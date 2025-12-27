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

    /// Creates a streaming message with Claude
    ///
    /// - Parameters:
    ///   - messages: Array of messages
    ///   - model: The model to use (default: "claude-sonnet-4-5-20250929")
    ///   - maxTokens: Maximum tokens to generate
    ///   - temperature: Sampling temperature between 0 and 1 (default: 0.7)
    ///   - onChunk: Closure called for each streamed chunk with delta content
    /// - Throws: AISecureError if the request fails
    public func createMessageStream(
        messages: [AnthropicMessage],
        model: String = "claude-sonnet-4-5-20250929",
        maxTokens: Int = 1024,
        temperature: Double = 0.7,
        onChunk: @escaping @Sendable (AnthropicStreamDelta) -> Void
    ) async throws {
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
            "temperature": temperature,
            "stream": true  // ⭐ Enable streaming
        ]

        try await streamRequest(
            endpoint: "/v1/messages",
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
        onChunk: @escaping @Sendable (AnthropicStreamDelta) -> Void
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
//                throw AISecureError.networkError("Invalid response type")
                throw AISecureError.invalidResponse
            }

            guard (200...299).contains(httpResponse.statusCode) else {
                // Don't consume the bytes iterator - just throw and let retry mechanism handle it
                throw AISecureError.httpError(status: httpResponse.statusCode, body: "HTTP \(httpResponse.statusCode)")
            }

            // Process Server-Sent Events (SSE)
            for try await line in bytes.lines {
                // Anthropic SSE format: "event: content_block_delta\ndata: {json}\n"
                if line.hasPrefix("data: ") {
                    let jsonString = String(line.dropFirst(6)) // Remove "data: " prefix
                    // Parse JSON chunk
                    if let data = jsonString.data(using: .utf8) {
                        do {
                            if let delta = try? JSONDecoder().decode(AnthropicStreamDelta.self, from: data) {
                                onChunk(delta)
                                if delta.type == "message_stop" {
                                    break
                                }
                            }
                        } catch {
                            // Skip malformed chunks
                            logIf(.debug)?.debug("Failed to decode chunk: \(error)")
                        }
                    }
                }
            }
            return (Data(), response) // Dummy return to satisfy executeWithRetry
        }
    }
}
