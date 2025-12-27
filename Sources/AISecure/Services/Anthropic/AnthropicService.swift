//
//  AnthropicService.swift
//  AISecure
//
//  Created by Diego Francisco Oruna Cabrera on 22/12/25.
//

import Foundation

@AISecureActor
public final class AnthropicService: Sendable {
    private let configuration: AISecureConfiguration
    private let requestBuilder: AISecureRequestBuilder
    private let urlSession: URLSession
    private let deviceAuthenticator: AISecureDeviceAuthenticator
    
    nonisolated init(
        configuration: AISecureConfiguration,
        requestBuilder: AISecureRequestBuilder,
        urlSession: URLSession,
        deviceAuthenticator: AISecureDeviceAuthenticator
    ) {
        self.configuration = configuration
        self.requestBuilder = requestBuilder
        self.urlSession = urlSession
        self.deviceAuthenticator = deviceAuthenticator
    }

    // MARK: - Public API

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
            "stream": true
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
            if let responseString = String(data: data, encoding: .utf8) {
                logIf(.error)?.error("❌ Decoding failed: \(responseString)")
            }
            throw AISecureError.decodingError(error.localizedDescription)
        }
    }

    private func streamRequest(
        endpoint: String,
        body: [String: Any],
        onChunk: @escaping @Sendable (AnthropicStreamDelta) -> Void
    ) async throws {
        let bodyData = try JSONSerialization.data(withJSONObject: body, options: [.sortedKeys])

        let _: (Data, URLResponse) = try await AISecureServiceHelpers.executeWithRetry(
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
                throw AISecureError.invalidResponse
            }

            guard (200...299).contains(httpResponse.statusCode) else {
                // Read error body for better error messages
                var errorData = Data()
                for try await byte in bytes {
                    errorData.append(byte)
                    if errorData.count > 1024 { break }
                }
                throw AISecureError.httpError(
                    status: httpResponse.statusCode,
                    body: HTTPErrorBody(from: errorData)
                )
            }

            // Process Anthropic SSE format
            for try await line in bytes.lines {
                if line.hasPrefix("data: ") {
                    let jsonString = String(line.dropFirst(6))
                    
                    if let data = jsonString.data(using: .utf8) {
                        if let delta = try? JSONDecoder().decode(AnthropicStreamDelta.self, from: data) {
                            onChunk(delta)
                            if delta.type == "message_stop" {
                                logIf(.debug)?.debug("⚡ Anthropic stream complete")
                                break
                            }
                        }
                    }
                }
            }
            
            return (Data(), response)
        }
    }
}
