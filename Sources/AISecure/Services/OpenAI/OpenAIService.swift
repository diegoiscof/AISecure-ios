//
//  OpenAIService.swift
//  AISecure
//
//  Created by Diego Francisco Oruna Cabrera on 22/12/25.
//

import Foundation

@AISecureActor public class OpenAIService: Sendable {
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


    /// Creates a chat completion request
    ///
    /// - Parameters:
    ///   - messages: Array of chat messages
    ///   - model: The model to use (default: "gpt-4")
    ///   - temperature: Sampling temperature between 0 and 2 (default: 0.7)
    /// - Returns: The chat completion response
    public func chat(
        messages: [ChatMessage],
        model: String = "",
        temperature: Double = 1
    ) async throws -> OpenAIChatResponse {
        guard !messages.isEmpty else {
            throw AISecureError.invalidConfiguration("Messages cannot be empty")
        }
        guard (0...2).contains(temperature) else {
            throw AISecureError.invalidConfiguration("Temperature must be between 0 and 2")
        }

        let body: [String: Any] = [
            "model": model,
            "messages": messages.map { ["role": $0.role, "content": $0.content] },
            "temperature": temperature
        ]

        return try await jsonRequest(
            endpoint: "/v1/chat/completions",
            body: body,
            response: OpenAIChatResponse.self
        )
    }

    /// Creates embeddings for the input text
    ///
    /// - Parameters:
    ///   - input: Array of strings to create embeddings for
    ///   - model: The model to use (default: "text-embedding-ada-002")
    /// - Returns: The embeddings response
    public func embeddings(
        input: [String],
        model: String = "text-embedding-ada-002"
    ) async throws -> OpenAIEmbeddingsResponse {
        guard !input.isEmpty else {
            throw AISecureError.invalidConfiguration("Input cannot be empty")
        }

        let body: [String: Any] = [
            "model": model,
            "input": input
        ]

        return try await jsonRequest(
            endpoint: "/v1/embeddings",
            body: body,
            response: OpenAIEmbeddingsResponse.self
        )
    }

    /// Converts text to speech
    ///
    /// - Parameters:
    ///   - input: The text to convert to speech
    ///   - model: The model to use (default: "tts-1")
    ///   - voice: The voice to use (default: "alloy")
    /// - Returns: Audio data
    public func textToSpeech(
        input: String,
        model: String = "tts-1",
        voice: String = "alloy"
    ) async throws -> Data {
        guard !input.isEmpty else {
            throw AISecureError.invalidConfiguration("Input cannot be empty")
        }

        let body: [String: Any] = [
            "model": model,
            "input": input,
            "voice": voice
        ]

        return try await binaryRequest(
            endpoint: "/v1/audio/speech",
            body: body
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

    private func binaryRequest(
        endpoint: String,
        body: [String: Any]
    ) async throws -> Data {
        let bodyData = try JSONSerialization.data(
            withJSONObject: body,
            options: [.sortedKeys]
        )

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
        return data
    }
}
