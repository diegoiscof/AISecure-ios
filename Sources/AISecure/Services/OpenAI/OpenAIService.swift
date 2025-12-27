//
//  OpenAIService.swift
//  AISecure
//
//  Created by Diego Francisco Oruna Cabrera on 22/12/25.
//

import Foundation

@AISecureActor public class OpenAIService: Sendable {
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


    /// Creates a chat completion request
    ///
    /// - Parameters:
    ///   - messages: Array of chat messages
    ///   - model: The model to use (default: "gpt-4")
    ///   - temperature: Sampling temperature between 0 and 2 (default: 0.7)
    ///   - responseFormat: Optional response format for structured outputs (JSON schema)
    ///   - reasoningEffort: Optional reasoning effort for o1/o3 models (none, low, medium, high)
    /// - Returns: The chat completion response
    public func chat(
        messages: [ChatMessage],
        model: String = "",
        temperature: Double = 1,
        responseFormat: ResponseFormat? = nil,
        reasoningEffort: ReasoningEffort? = nil
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

        // Add response format if provided (for structured outputs)
        if let responseFormat = responseFormat {
            body["response_format"] = responseFormat.toDictionary()
        }

        // Add reasoning effort if provided (for o1/o3 models)
        if let reasoningEffort = reasoningEffort {
            body["reasoning_effort"] = reasoningEffort.rawValue
        }

        return try await jsonRequest(
            endpoint: "/v1/chat/completions",
            body: body,
            response: OpenAIChatResponse.self
        )
    }

    /// Creates a response using OpenAI's Responses API (most advanced interface)
    /// Supports o1, o3, and other advanced models with reasoning capabilities
    ///
    /// - Parameters:
    ///   - input: Text input to the model
    ///   - model: The model to use (e.g., "o1", "o3-mini", "gpt-4o")
    ///   - temperature: Sampling temperature between 0 and 2 (default: 1)
    ///   - reasoningEffort: Reasoning effort (none, low, medium, high)
    /// - Returns: The response object
    public func createResponse(
        input: String,
        model: String,
        temperature: Double = 1,
        reasoningEffort: ReasoningEffort? = nil
    ) async throws -> OpenAIResponseObject {
        guard !input.isEmpty else {
            throw AISecureError.invalidConfiguration("Input cannot be empty")
        }
        guard (0...2).contains(temperature) else {
            throw AISecureError.invalidConfiguration("Temperature must be between 0 and 2")
        }

        var body: [String: Any] = [
            "model": model,
            "input": input,
            "temperature": temperature
        ]

        // Add reasoning configuration if provided
        if let reasoningEffort = reasoningEffort {
            body["reasoning"] = ["effort": reasoningEffort.rawValue]
        }

        return try await jsonRequest(
            endpoint: "/v1/responses",
            body: body,
            response: OpenAIResponseObject.self
        )
    }

    /// Creates a streaming response using OpenAI's Responses API
    ///
    /// - Parameters:
    ///   - input: Text input to the model
    ///   - model: The model to use
    ///   - temperature: Sampling temperature between 0 and 2 (default: 1)
    ///   - reasoningEffort: Reasoning effort for o1/o3 models
    ///   - onChunk: Closure called for each streamed response event
    public func createResponseStream(
        input: String,
        model: String,
        temperature: Double = 1,
        reasoningEffort: ReasoningEffort? = nil,
        onChunk: @escaping @Sendable (OpenAIResponseStreamEvent) -> Void
    ) async throws {
        guard !input.isEmpty else {
            throw AISecureError.invalidConfiguration("Input cannot be empty")
        }
        guard (0...2).contains(temperature) else {
            throw AISecureError.invalidConfiguration("Temperature must be between 0 and 2")
        }

        var body: [String: Any] = [
            "model": model,
            "input": input,
            "temperature": temperature,
            "stream": true
        ]

        if let reasoningEffort = reasoningEffort {
            body["reasoning"] = ["effort": reasoningEffort.rawValue]
        }

        try await streamResponseRequest(
            endpoint: "/v1/responses",
            body: body,
            onChunk: onChunk
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

    /// Generates images using DALL-E
    ///
    /// - Parameters:
    ///   - prompt: A text description of the desired image(s)
    ///   - model: The model to use (default: "dall-e-3")
    ///   - n: Number of images to generate (1-10, default: 1)
    ///   - size: Size of generated images (default: "1024x1024")
    ///   - quality: Quality of image (default: "standard")
    ///   - responseFormat: Format of response - "url" or "b64_json" (default: "url")
    /// - Returns: Image generation response
    public func generateImage(
        prompt: String,
        model: String = "dall-e-3",
        n: Int = 1,
        size: String = "1024x1024",
        quality: String = "standard",
        responseFormat: String = "url"
    ) async throws -> OpenAIImageGenerationResponse {
        guard !prompt.isEmpty else {
            throw AISecureError.invalidConfiguration("Prompt cannot be empty")
        }
        guard (1...10).contains(n) else {
            throw AISecureError.invalidConfiguration("Number of images must be between 1 and 10")
        }

        let body: [String: Any] = [
            "model": model,
            "prompt": prompt,
            "n": n,
            "size": size,
            "quality": quality,
            "response_format": responseFormat
        ]

        return try await jsonRequest(
            endpoint: "/v1/images/generations",
            body: body,
            response: OpenAIImageGenerationResponse.self
        )
    }

    /// Moderates text content for harmful content
    ///
    /// - Parameters:
    ///   - input: The text to moderate
    ///   - model: The model to use (default: "omni-moderation-latest")
    /// - Returns: Moderation response with flagged categories
    public func moderateContent(
        input: String,
        model: String = "omni-moderation-latest"
    ) async throws -> OpenAIModerationResponse {
        guard !input.isEmpty else {
            throw AISecureError.invalidConfiguration("Input cannot be empty")
        }

        let body: [String: Any] = [
            "model": model,
            "input": input
        ]

        return try await jsonRequest(
            endpoint: "/v1/moderations",
            body: body,
            response: OpenAIModerationResponse.self
        )
    }

    /// Creates a streaming chat completion request
    ///
    /// - Parameters:
    ///   - messages: Array of chat messages
    ///   - model: The model to use (default: "gpt-4")
    ///   - temperature: Sampling temperature between 0 and 2 (default: 1)
    ///   - responseFormat: Optional response format for structured outputs
    ///   - reasoningEffort: Optional reasoning effort for o1/o3 models
    ///   - onChunk: Closure called for each streamed chunk with delta content
    /// - Throws: AISecureError if the request fails
    public func chatStream(
        messages: [ChatMessage],
        model: String = "",
        temperature: Double = 1,
        responseFormat: ResponseFormat? = nil,
        reasoningEffort: ReasoningEffort? = nil,
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

        if let responseFormat = responseFormat {
            body["response_format"] = responseFormat.toDictionary()
        }

        if let reasoningEffort = reasoningEffort {
            body["reasoning_effort"] = reasoningEffort.rawValue
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

    private func binaryRequest(
        endpoint: String,
        body: [String: Any]
    ) async throws -> Data {
        let bodyData = try JSONSerialization.data(withJSONObject: body, options: [.sortedKeys])
        
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
        return data
    }

    private func streamRequest(
        endpoint: String,
        body: [String: Any],
        onChunk: @escaping @Sendable (OpenAIChatStreamDelta) -> Void
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
                    if errorData.count > 1024 { break } // Limit error body size
                }
                throw AISecureError.httpError(
                    status: httpResponse.statusCode,
                    body: HTTPErrorBody(from: errorData)
                )
            }
            
            // Process SSE stream
            for try await line in bytes.lines {
                if line.hasPrefix("data: ") {
                    let jsonString = String(line.dropFirst(6))
                    
                    if jsonString == "[DONE]" {
                        logIf(.debug)?.debug("⚡ Stream complete")
                        break
                    }
                    
                    if let data = jsonString.data(using: .utf8) {
                        do {
                            let delta = try JSONDecoder().decode(OpenAIChatStreamDelta.self, from: data)
                            onChunk(delta)
                        } catch {
                            logIf(.debug)?.debug("Skipping malformed chunk: \(error.localizedDescription)")
                        }
                    }
                }
            }
            
            return (Data(), response)
        }
    }

    private func streamResponseRequest(
        endpoint: String,
        body: [String: Any],
        onChunk: @escaping @Sendable (OpenAIResponseStreamEvent) -> Void
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
            
            // Process SSE with event-based format
            for try await line in bytes.lines {
                if line.hasPrefix("event: ") {
                    // Event name - could track if needed
                    continue
                }
                
                if line.hasPrefix("data: ") {
                    let jsonString = String(line.dropFirst(6))
                    
                    if jsonString == "[DONE]" {
                        logIf(.debug)?.debug("⚡ Response stream complete")
                        break
                    }
                    
                    if let data = jsonString.data(using: .utf8) {
                        do {
                            let event = try JSONDecoder().decode(OpenAIResponseStreamEvent.self, from: data)
                            onChunk(event)
                        } catch {
                            logIf(.debug)?.debug("Skipping malformed event: \(error.localizedDescription)")
                        }
                    }
                }
            }
            
            return (Data(), response)
        }
    }
}

// MARK: - Supporting Types

/// Response format for structured outputs with JSON schema
public enum ResponseFormat {
    case jsonObject
    case jsonSchema(name: String, schema: [String: Any], strict: Bool)
    case text

    func toDictionary() -> [String: Any] {
        switch self {
        case .jsonObject:
            return ["type": "json_object"]
        case .jsonSchema(let name, let schema, let strict):
            return [
                "type": "json_schema",
                "json_schema": [
                    "name": name,
                    "schema": schema,
                    "strict": strict
                ]
            ]
        case .text:
            return ["type": "text"]
        }
    }
}

/// Reasoning effort for o1/o3 models
public enum ReasoningEffort: String {
    case none = "none"
    case minimal = "minimal"
    case low = "low"
    case medium = "medium"
    case high = "high"
}
