//
//  AnthropicService.swift
//  AISecure
//
//  Created by Diego Francisco Oruna Cabrera on 22/12/25.
//

import Foundation

@AISecureActor public class AnthropicService: Sendable {
    private let configuration: AISecureConfiguration
    private let sessionManager: AISecureSessionManager
    private let requestBuilder: AISecureRequestBuilder
    private let urlSession: URLSession

    nonisolated init(
        configuration: AISecureConfiguration,
        sessionManager: AISecureSessionManager,
        requestBuilder: AISecureRequestBuilder,
        urlSession: URLSession
    ) {
        self.configuration = configuration
        self.sessionManager = sessionManager
        self.requestBuilder = requestBuilder
        self.urlSession = urlSession
    }

    /// Creates a message completion request
    ///
    /// - Parameters:
    ///   - messages: Array of messages in the conversation
    ///   - model: The model to use (default: "claude-3-5-sonnet-20241022")
    ///   - maxTokens: Maximum tokens to generate (default: 1024)
    ///   - temperature: Sampling temperature between 0 and 1 (default: 1.0)
    ///   - system: Optional system prompt
    /// - Returns: The message response
    public func createMessage(
        messages: [AnthropicMessage],
        model: String = "claude-sonnet-4-5-20250929",
        maxTokens: Int = 1024,
        temperature: Double = 1.0,
        system: String? = nil
    ) async throws -> AnthropicMessageResponse {
        guard !messages.isEmpty else {
            throw AISecureError.invalidConfiguration("Messages cannot be empty")
        }
        guard maxTokens > 0 else {
            throw AISecureError.invalidConfiguration("Max tokens must be greater than 0")
        }
        guard (0...1).contains(temperature) else {
            throw AISecureError.invalidConfiguration("Temperature must be between 0 and 1")
        }

        var body: [String: Any] = [
            "model": model,
            "max_tokens": maxTokens,
            "messages": messages.map { ["role": $0.role, "content": $0.content] }
        ]

        if let system = system {
            body["system"] = system
        }

        if temperature != 1.0 {
            body["temperature"] = temperature
        }

        return try await jsonRequest(
            provider: "anthropic",
            endpoint: "/v1/messages",
            body: body,
            response: AnthropicMessageResponse.self
        )
    }

    /// Creates a message completion with streaming disabled (alias for createMessage)
    ///
    /// - Parameters:
    ///   - messages: Array of messages in the conversation
    ///   - model: The model to use
    ///   - maxTokens: Maximum tokens to generate
    ///   - temperature: Sampling temperature
    ///   - system: Optional system prompt
    /// - Returns: The message response
    public func messages(
        messages: [AnthropicMessage],
        model: String = "claude-3-5-sonnet-20241022",
        maxTokens: Int = 1024,
        temperature: Double = 1.0,
        system: String? = nil
    ) async throws -> AnthropicMessageResponse {
        return try await createMessage(
            messages: messages,
            model: model,
            maxTokens: maxTokens,
            temperature: temperature,
            system: system
        )
    }

    // MARK: - Private Methods

    private func jsonRequest<T: Decodable>(
        provider: String,
        endpoint: String,
        body: [String: Any],
        response: T.Type
    ) async throws -> T {
        let session = try await sessionManager.getValidSession()
        let service = configuration.service

        let bodyData = try JSONSerialization.data(withJSONObject: body)
        var request = requestBuilder.buildRequest(
            endpoint: endpoint,
            body: bodyData,
            session: session,
            service: service
        )

        // Add Anthropic-specific headers
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")

        let (data, urlResponse) = try await urlSession.data(for: request)
        try validate(response: urlResponse, data: data)

        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw AISecureError.decodingError(error)
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
