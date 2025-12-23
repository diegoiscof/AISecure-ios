// The Swift Programming Language
// https://docs.swift.org/swift-book

import Foundation

public enum AISecure {

    /// The current SDK version
    nonisolated public static let sdkVersion = "2.0.0"

    /// Configures the AISecure SDK logging level
    ///
    /// - Parameter logLevel: The minimum log level to display
    nonisolated public static func configure(logLevel: AISecureLogLevel) {
        AISecureLogLevel.callerDesiredLogLevel = logLevel
    }

    // MARK: - Service Initialization

    /// Creates an OpenAI service instance
    ///
    /// 🔒 SECURITY: Credentials are fetched dynamically from backend (no hardcoded keys)
    ///
    /// Features:
    /// - Full OpenAI API support (chat, embeddings, audio, vision, etc.)
    /// - Model can be specified from SDK or configured in dashboard
    /// - Raw OpenAI response format
    /// - Dynamic credential issuance via JWT
    ///
    /// - Parameters:
    ///   - serviceURL: The service gateway URL (format: https://api.gateway.com/openai-{serviceId})
    ///   - backendURL: The AISecure backend URL
    ///
    /// - Returns: An instance of OpenAIService configured and ready to make requests
    ///
    /// - Throws: AISecureError if the configuration is invalid
    @MainActor
    public static func openAIService(
        serviceURL: String,
        backendURL: String
    ) throws -> OpenAIService {
        let (configuration, sessionManager, requestBuilder, urlSession, deviceAuth) = try createServiceDependenciesWithJWT(
            provider: "openai",
            serviceURL: serviceURL,
            backendURL: backendURL
        )

        return OpenAIService(
            configuration: configuration,
            sessionManager: sessionManager,
            requestBuilder: requestBuilder,
            urlSession: urlSession,
            deviceAuthenticator: deviceAuth
        )
    }

    /// Creates an Anthropic service instance
    ///
    /// 🔒 SECURITY: Credentials are fetched dynamically from backend (no hardcoded keys)
    ///
    /// Features:
    /// - Full Anthropic API support (messages, function calling, vision, etc.)
    /// - Model can be specified from SDK or configured in dashboard
    /// - Raw Anthropic response format
    /// - Dynamic credential issuance via JWT
    ///
    /// - Parameters:
    ///   - serviceURL: The service gateway URL (format: https://api.gateway.com/anthropic-{serviceId})
    ///   - backendURL: The AISecure backend URL
    ///
    /// - Returns: An instance of AnthropicService configured and ready to make requests
    ///
    /// - Throws: AISecureError if the configuration is invalid
    @MainActor
    public static func anthropicService(
        serviceURL: String,
        backendURL: String
    ) throws -> AnthropicService {
        let (configuration, sessionManager, requestBuilder, urlSession, deviceAuth) = try createServiceDependenciesWithJWT(
            provider: "anthropic",
            serviceURL: serviceURL,
            backendURL: backendURL
        )

        return AnthropicService(
            configuration: configuration,
            sessionManager: sessionManager,
            requestBuilder: requestBuilder,
            urlSession: urlSession,
            deviceAuthenticator: deviceAuth
        )
    }

    /// Creates an Anthropic service instance (Legacy - with hardcoded credentials)
    ///
    /// ⚠️ DEPRECATED: This method requires hardcoded credentials which can be extracted from your app.
    /// Use `anthropicService(serviceURL:backendURL:)` instead for JWT-based dynamic credentials.
    ///
    /// - Parameters:
    ///   - serviceURL: The service gateway URL (format: https://api.gateway.com/anthropic-{serviceId})
    ///   - partialKey: The partial API key
    ///   - backendURL: The AISecure backend URL
    ///
    /// - Returns: An instance of AnthropicService configured and ready to make requests
    ///
    /// - Throws: AISecureError if the configuration is invalid
    @available(*, deprecated, message: "Use anthropicService(serviceURL:backendURL:) for JWT-based authentication instead")
    @MainActor
    public static func anthropicServiceLegacy(
        serviceURL: String,
        partialKey: String,
        backendURL: String
    ) throws -> AnthropicService {
        let service = try AISecureServiceConfig(
            provider: "anthropic",
            serviceURL: serviceURL,
            partialKey: partialKey
        )

        let (configuration, sessionManager, requestBuilder, urlSession) = try createServiceDependencies(
            service: service,
            backendURL: backendURL
        )

        return AnthropicService(
            configuration: configuration,
            sessionManager: sessionManager,
            requestBuilder: requestBuilder,
            urlSession: urlSession
        )
    }

    // MARK: - Private Helpers

    /// Creates service dependencies with JWT-based authentication
    /// 🔒 SECURITY: Credentials fetched dynamically from backend, no hardcoded keys
    @MainActor
    private static func createServiceDependenciesWithJWT(
        provider: String,
        serviceURL: String,
        backendURL: String
    ) throws -> (AISecureConfiguration, AISecureSessionManager, AISecureRequestBuilder, URLSession, AISecureDeviceAuthenticator) {
        guard let url = URL(string: backendURL) else {
            throw AISecureError.invalidConfiguration("Invalid backend URL: \(backendURL)")
        }

        let deviceFingerprint = DeviceFingerprint.generate()
        let urlSession = createURLSession()
        let storage = AISecureStorage()

        // Create device authenticator (gets JWT with dynamic credentials)
        let deviceAuth = AISecureDeviceAuthenticator(
            backendURL: url,
            serviceURL: serviceURL,
            deviceFingerprint: deviceFingerprint,
            urlSession: urlSession,
            storage: storage
        )

        // Temporary service config (will be replaced with JWT credentials)
        let temporaryService = try AISecureServiceConfig(
            provider: provider,
            serviceURL: serviceURL,
            partialKey: "temporary" // Will be replaced by JWT payload
        )

        let configuration = AISecureConfiguration(
            backendURL: url,
            deviceFingerprint: deviceFingerprint,
            service: temporaryService
        )

        let sessionManager = AISecureSessionManager(
            configuration: configuration,
            storage: storage,
            urlSession: urlSession
        )
        let requestBuilder = AISecureDefaultRequestBuilder(configuration: configuration)

        return (configuration, sessionManager, requestBuilder, urlSession, deviceAuth)
    }

    @MainActor
    private static func createServiceDependencies(
        service: AISecureServiceConfig,
        backendURL: String
    ) throws -> (AISecureConfiguration, AISecureSessionManager, AISecureRequestBuilder, URLSession) {
        guard let url = URL(string: backendURL) else {
            throw AISecureError.invalidConfiguration("Invalid backend URL: \(backendURL)")
        }

        let deviceFingerprint = DeviceFingerprint.generate()

        let configuration = AISecureConfiguration(
            backendURL: url,
            deviceFingerprint: deviceFingerprint,
            service: service
        )

        let urlSession = createURLSession()
        let storage = AISecureStorage()
        let sessionManager = AISecureSessionManager(
            configuration: configuration,
            storage: storage,
            urlSession: urlSession
        )
        let requestBuilder = AISecureDefaultRequestBuilder(configuration: configuration)

        return (configuration, sessionManager, requestBuilder, urlSession)
    }

    /// Creates a URLSession configured for AISecure
    private static func createURLSession() -> URLSession {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        return URLSession(configuration: config)
    }
}
