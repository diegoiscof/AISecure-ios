//
//  SilentLayer.swift
//  SilentLayer
//
//  Created by Diego Francisco Oruna Cabrera on 22/12/25.
//

import Foundation

// MARK: - SilentLayer SDK

/// SilentLayer SDK - Secure AI API proxy for iOS applications
///
/// SilentLayer provides a secure way to access AI providers (OpenAI, Anthropic, Google, xAI)
/// without exposing API keys in your mobile app. Features include:
///
/// - **Security**: API keys never leave your server. Requests are authenticated via JWT.
/// - **Multi-provider**: Single SDK for OpenAI, Anthropic, Gemini, and Grok.
/// - **Usage tracking**: Monitor API usage per project from your dashboard.
/// - **Streaming**: Full support for streaming responses.
///
/// ## Quick Start
///
/// 1. Configure the SDK at app launch (optional):
/// ```swift
/// SilentLayer.configure(logLevel: .error)
/// ```
///
/// 2. Create a service using the Service URL from your dashboard:
/// ```swift
/// let openAI = try SilentLayer.openAIService(
///     serviceURL: "https://gateway.silentlayer.io/openai-abc123"
/// )
///
/// let response = try await openAI.chat(
///     messages: [.init(role: "user", content: "Hello!")],
///     model: "gpt-4o-mini"
/// )
/// ```
public enum SilentLayer {
    
    /// The current SDK version
    public static let sdkVersion = "2.1.0"
    
    // MARK: - Configuration
    
    /// Production backend URL
    private static let backendURL = "https://relates-treasury-pot-generate.trycloudflare.com"
    
    /// Configures the SilentLayer SDK logging
    ///
    /// Call this once at app startup. This is optional - defaults to `.error` level.
    ///
    /// - Parameters:
    ///   - logLevel: The minimum log level to display (default: `.error`)
    ///   - timestamps: Whether to include timestamps in logs (default: `false`)
    ///
    /// ## Example
    ///
    /// ```swift
    /// // Minimal logging (recommended for production)
    /// SilentLayer.configure(logLevel: .error)
    ///
    /// // Verbose logging (for debugging)
    /// SilentLayer.configure(logLevel: .debug, timestamps: true)
    /// ```
    nonisolated public static func configure(
        logLevel: SilentLayerLogLevel = .error,
        timestamps: Bool = false
    ) {
        SilentLayerLogLevel.callerDesiredLogLevel = logLevel
        SilentLayerLogLevel.showTimestamps = timestamps
        
        logIf(.info)?.info("SilentLayer SDK v\(sdkVersion) initialized")
    }
    
    // MARK: - Service Factory
    
    /// Creates an OpenAI service instance
    ///
    /// 🔒 **Security**: Credentials are fetched dynamically from backend via JWT.
    /// No API keys are stored in your app.
    ///
    /// ## Supported Features
    /// - Chat completions (GPT-4, GPT-4o, etc.)
    /// - Streaming responses
    /// - Structured outputs (JSON schema)
    /// - Reasoning models (o1, o3)
    /// - Responses API
    /// - Image generation (DALL-E)
    /// - Embeddings
    /// - Text-to-speech
    /// - Content moderation
    ///
    /// - Parameter serviceURL: The Service URL from your SilentLayer dashboard
    /// - Returns: An instance of `OpenAIService` ready to make requests
    /// - Throws: `SilentLayerError.invalidConfiguration` if the URL is invalid
    ///
    /// ## Example
    ///
    /// ```swift
    /// let openAI = try SilentLayer.openAIService(
    ///     serviceURL: "https://gateway.silentlayer.io/openai-abc123"
    /// )
    ///
    /// // Non-streaming
    /// let response = try await openAI.chat(
    ///     messages: [.init(role: "user", content: "Hello!")],
    ///     model: "gpt-4o-mini"
    /// )
    ///
    /// // Streaming
    /// try await openAI.chatStream(
    ///     messages: [.init(role: "user", content: "Tell me a story")],
    ///     model: "gpt-4o-mini"
    /// ) { delta in
    ///     print(delta.choices.first?.delta.content ?? "", terminator: "")
    /// }
    /// ```
    @MainActor
    public static func openAIService(serviceURL: String) throws -> OpenAIService {
        let deps = try createDependencies(serviceURL: serviceURL)
        return OpenAIService(
            configuration: deps.configuration,
            requestBuilder: deps.requestBuilder,
            urlSession: deps.urlSession,
            deviceAuthenticator: deps.authenticator
        )
    }
    
    /// Creates an Anthropic service instance
    ///
    /// 🔒 **Security**: Credentials are fetched dynamically from backend via JWT.
    /// No API keys are stored in your app.
    ///
    /// ## Supported Features
    /// - Messages API (Claude 3.5, Claude 3, etc.)
    /// - Streaming responses
    /// - Vision (image inputs)
    /// - Extended thinking
    ///
    /// - Parameter serviceURL: The Service URL from your SilentLayer dashboard
    /// - Returns: An instance of `AnthropicService` ready to make requests
    /// - Throws: `SilentLayerError.invalidConfiguration` if the URL is invalid
    ///
    /// ## Example
    ///
    /// ```swift
    /// let anthropic = try SilentLayer.anthropicService(
    ///     serviceURL: "https://gateway.silentlayer.io/anthropic-abc123"
    /// )
    ///
    /// let response = try await anthropic.createMessage(
    ///     messages: [.init(role: "user", content: "Hello!")],
    ///     maxTokens: 1024
    /// )
    /// print(response.content.first?.text ?? "")
    /// ```
    @MainActor
    public static func anthropicService(serviceURL: String) throws -> AnthropicService {
        let deps = try createDependencies(serviceURL: serviceURL)
        return AnthropicService(
            configuration: deps.configuration,
            requestBuilder: deps.requestBuilder,
            urlSession: deps.urlSession,
            deviceAuthenticator: deps.authenticator
        )
    }
    
    /// Creates a Gemini service instance
    ///
    /// 🔒 **Security**: Credentials are fetched dynamically from backend via JWT.
    /// No API keys are stored in your app.
    ///
    /// ## Supported Features
    /// - Content generation (Gemini Pro, Gemini Flash, etc.)
    /// - Streaming responses
    /// - Multi-modal inputs (text + images)
    /// - Safety settings
    ///
    /// - Parameter serviceURL: The Service URL from your SilentLayer dashboard
    /// - Returns: An instance of `GeminiService` ready to make requests
    /// - Throws: `SilentLayerError.invalidConfiguration` if the URL is invalid
    ///
    /// ## Example
    ///
    /// ```swift
    /// let gemini = try SilentLayer.geminiService(
    ///     serviceURL: "https://gateway.silentlayer.io/google-abc123"
    /// )
    ///
    /// let response = try await gemini.generateContent(
    ///     prompt: "Write a haiku about Swift",
    ///     model: "gemini-2.0-flash-exp"
    /// )
    /// print(response.candidates?.first?.content?.parts.first?.text ?? "")
    /// ```
    @MainActor
    public static func geminiService(serviceURL: String) throws -> GeminiService {
        let deps = try createDependencies(serviceURL: serviceURL)
        return GeminiService(
            configuration: deps.configuration,
            requestBuilder: deps.requestBuilder,
            urlSession: deps.urlSession,
            deviceAuthenticator: deps.authenticator
        )
    }
    
    /// Creates a Grok service instance
    ///
    /// 🔒 **Security**: Credentials are fetched dynamically from backend via JWT.
    /// No API keys are stored in your app.
    ///
    /// ## Supported Features
    /// - Chat completions (OpenAI-compatible API)
    /// - Streaming responses
    /// - Vision capabilities
    /// - Reasoning models
    ///
    /// - Parameter serviceURL: The Service URL from your SilentLayer dashboard
    /// - Returns: An instance of `GrokService` ready to make requests
    /// - Throws: `SilentLayerError.invalidConfiguration` if the URL is invalid
    ///
    /// ## Example
    ///
    /// ```swift
    /// let grok = try SilentLayer.grokService(
    ///     serviceURL: "https://gateway.silentlayer.io/grok-abc123"
    /// )
    ///
    /// let response = try await grok.chat(
    ///     messages: [.init(role: "user", content: "Hello!")],
    ///     model: "grok-2-latest"
    /// )
    /// print(response.choices.first?.message.content ?? "")
    /// ```
    @MainActor
    public static func grokService(serviceURL: String) throws -> GrokService {
        let deps = try createDependencies(serviceURL: serviceURL)
        return GrokService(
            configuration: deps.configuration,
            requestBuilder: deps.requestBuilder,
            urlSession: deps.urlSession,
            deviceAuthenticator: deps.authenticator
        )
    }
    
    // MARK: - Private
    
    private struct ServiceDependencies {
        let configuration: SilentLayerConfiguration
        let requestBuilder: SilentLayerRequestBuilder
        let urlSession: URLSession
        let authenticator: SilentLayerDeviceAuthenticator
    }
    
    @MainActor
    private static func createDependencies(serviceURL: String) throws -> ServiceDependencies {
        guard let backendURLParsed = URL(string: backendURL) else {
            throw SilentLayerError.invalidConfiguration("Invalid backend URL")
        }
        
        let deviceFingerprint = DeviceIdentifier.get()
        let urlSession = createURLSession()
        let storage = SilentLayerStorage()
        
        let authenticator = SilentLayerDeviceAuthenticator(
            backendURL: backendURLParsed,
            serviceURL: serviceURL,
            deviceFingerprint: deviceFingerprint,
            urlSession: urlSession,
            storage: storage
        )
        
        let configuration = SilentLayerConfiguration(
            backendURL: backendURLParsed,
            deviceFingerprint: deviceFingerprint,
            serviceURL: serviceURL
        )
        
        let requestBuilder = SilentLayerDefaultRequestBuilder(configuration: configuration)
        
        return ServiceDependencies(
            configuration: configuration,
            requestBuilder: requestBuilder,
            urlSession: urlSession,
            authenticator: authenticator
        )
    }
    
    private static func createURLSession() -> URLSession {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        return URLSession(configuration: config)
    }
}
