//
//  GrokService.swift
//  SilentLayer
//
//  Created by Diego Francisco Oruna Cabrera on 26/12/25.
//

import Foundation

@SilentLayerActor
public final class GrokService: Sendable {
    private let configuration: SilentLayerConfiguration
    private let requestBuilder: SilentLayerRequestBuilder
    private let urlSession: URLSession
    private let deviceAuthenticator: SilentLayerDeviceAuthenticator
    
    nonisolated init(
        configuration: SilentLayerConfiguration,
        requestBuilder: SilentLayerRequestBuilder,
        urlSession: URLSession,
        deviceAuthenticator: SilentLayerDeviceAuthenticator
    ) {
        self.configuration = configuration
        self.requestBuilder = requestBuilder
        self.urlSession = urlSession
        self.deviceAuthenticator = deviceAuthenticator
    }

    // MARK: - Public API

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
            throw SilentLayerError.invalidConfiguration("Messages cannot be empty")
        }
        guard (0...2).contains(temperature) else {
            throw SilentLayerError.invalidConfiguration("Temperature must be between 0 and 2")
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
            throw SilentLayerError.invalidConfiguration("Messages cannot be empty")
        }
        guard (0...2).contains(temperature) else {
            throw SilentLayerError.invalidConfiguration("Temperature must be between 0 and 2")
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
    /// - Throws: SilentLayerError if the request fails
    public func chatStream(
        messages: [ChatMessage],
        model: String = "grok-4",
        temperature: Double = 0.7,
        maxTokens: Int? = nil,
        onChunk: @escaping @Sendable (OpenAIChatStreamDelta) -> Void
    ) async throws {
        guard !messages.isEmpty else {
            throw SilentLayerError.invalidConfiguration("Messages cannot be empty")
        }
        guard (0...2).contains(temperature) else {
            throw SilentLayerError.invalidConfiguration("Temperature must be between 0 and 2")
        }

        var body: [String: Any] = [
            "model": model,
            "messages": messages.map { ["role": $0.role, "content": $0.content] },
            "temperature": temperature,
            "stream": true
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
        
        let (data, urlResponse) = try await SilentLayerServiceHelpers.executeWithRetry(
            deviceAuthenticator: deviceAuthenticator,
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
        
        try SilentLayerServiceHelpers.validateResponse(urlResponse, data: data)
        
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            if let responseString = String(data: data, encoding: .utf8) {
                logIf(.error)?.error("❌ Decoding failed: \(responseString)")
            }
            throw SilentLayerError.decodingError(error.localizedDescription)
        }
    }

    private func streamRequest(
        endpoint: String,
        body: [String: Any],
        onChunk: @escaping @Sendable (OpenAIChatStreamDelta) -> Void
    ) async throws {
        let bodyData = try JSONSerialization.data(withJSONObject: body, options: [.sortedKeys])

        let _: (Data, URLResponse) = try await SilentLayerServiceHelpers.executeWithRetry(
            deviceAuthenticator: deviceAuthenticator,
            configuration: configuration
        ) { service, session in
            let request = self.requestBuilder.buildRequest(
                endpoint: endpoint,
                body: bodyData,
                session: session,
                service: service
            )

            let (bytes, response) = try await self.urlSession.bytes(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw SilentLayerError.invalidResponse
            }

            guard (200...299).contains(httpResponse.statusCode) else {
                // Read error body for better error messages
                var errorData = Data()
                for try await byte in bytes {
                    errorData.append(byte)
                    if errorData.count > 1024 { break }
                }
                throw SilentLayerError.httpError(
                    status: httpResponse.statusCode,
                    body: HTTPErrorBody(from: errorData)
                )
            }

            // Process OpenAI-compatible SSE format
            for try await line in bytes.lines {
                if line.hasPrefix("data: ") {
                    let jsonString = String(line.dropFirst(6))

                    if jsonString == "[DONE]" {
                        logIf(.debug)?.debug("⚡ Grok stream complete")
                        break
                    }

                    if let data = jsonString.data(using: .utf8) {
                        do {
                            let delta = try JSONDecoder().decode(OpenAIChatStreamDelta.self, from: data)
                            onChunk(delta)
                        } catch {
                            logIf(.debug)?.debug("Skipping malformed Grok chunk: \(error.localizedDescription)")
                        }
                    }
                }
            }

            return (Data(), response)
        }
    }
}
