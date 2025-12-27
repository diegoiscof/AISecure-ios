//
//  GeminiService.swift
//  AISecure
//
//  Created by Diego Francisco Oruna Cabrera on 26/12/25.
//

import Foundation

@AISecureActor public class GeminiService: Sendable {
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

    /// Generates content using Gemini models
    ///
    /// - Parameters:
    ///   - prompt: The text prompt to generate content from
    ///   - model: The model to use (default: "gemini-2.0-flash-exp")
    ///   - generationConfig: Optional generation configuration
    ///   - safetySettings: Optional safety settings
    /// - Returns: The generated content response
    public func generateContent(
        prompt: String,
        model: String = "gemini-2.0-flash-exp",
        generationConfig: GeminiGenerationConfig? = nil,
        safetySettings: [GeminiSafetySetting]? = nil
    ) async throws -> GeminiGenerateContentResponse {
        guard !prompt.isEmpty else {
            throw AISecureError.invalidConfiguration("Prompt cannot be empty")
        }

        var body: [String: Any] = [
            "contents": [
                [
                    "parts": [
                        ["text": prompt]
                    ]
                ]
            ]
        ]

        if let config = generationConfig {
            var configDict: [String: Any] = [:]
            if let temp = config.temperature { configDict["temperature"] = temp }
            if let topP = config.topP { configDict["topP"] = topP }
            if let topK = config.topK { configDict["topK"] = topK }
            if let count = config.candidateCount { configDict["candidateCount"] = count }
            if let maxTokens = config.maxOutputTokens { configDict["maxOutputTokens"] = maxTokens }
            if let stops = config.stopSequences { configDict["stopSequences"] = stops }

            if !configDict.isEmpty {
                body["generationConfig"] = configDict
            }
        }

        if let settings = safetySettings {
            body["safetySettings"] = settings.map { setting in
                ["category": setting.category, "threshold": setting.threshold]
            }
        }

        return try await jsonRequest(
            endpoint: "/v1beta/models/\(model):generateContent",
            body: body,
            response: GeminiGenerateContentResponse.self
        )
    }

    /// Generates content with multi-part input (text + images)
    ///
    /// - Parameters:
    ///   - parts: Array of content parts (text and/or images)
    ///   - model: The model to use (default: "gemini-2.0-flash-exp")
    ///   - generationConfig: Optional generation configuration
    ///   - safetySettings: Optional safety settings
    /// - Returns: The generated content response
    public func generateContentWithParts(
        parts: [[String: Any]],
        model: String = "gemini-2.0-flash-exp",
        generationConfig: GeminiGenerationConfig? = nil,
        safetySettings: [GeminiSafetySetting]? = nil
    ) async throws -> GeminiGenerateContentResponse {
        guard !parts.isEmpty else {
            throw AISecureError.invalidConfiguration("Parts cannot be empty")
        }

        var body: [String: Any] = [
            "contents": [
                ["parts": parts]
            ]
        ]

        if let config = generationConfig {
            var configDict: [String: Any] = [:]
            if let temp = config.temperature { configDict["temperature"] = temp }
            if let topP = config.topP { configDict["topP"] = topP }
            if let topK = config.topK { configDict["topK"] = topK }
            if let count = config.candidateCount { configDict["candidateCount"] = count }
            if let maxTokens = config.maxOutputTokens { configDict["maxOutputTokens"] = maxTokens }
            if let stops = config.stopSequences { configDict["stopSequences"] = stops }

            if !configDict.isEmpty {
                body["generationConfig"] = configDict
            }
        }

        if let settings = safetySettings {
            body["safetySettings"] = settings.map { setting in
                ["category": setting.category, "threshold": setting.threshold]
            }
        }

        return try await jsonRequest(
            endpoint: "/v1beta/models/\(model):generateContent",
            body: body,
            response: GeminiGenerateContentResponse.self
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
}
