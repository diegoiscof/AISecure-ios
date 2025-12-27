//
//  AISecure.swift
//  AISecure
//

import Foundation

public enum AISecure {
    
    public static let sdkVersion = "2.1.0"
    
    // MARK: - Configuration
    
    nonisolated public static func configure(logLevel: AISecureLogLevel, timestamps: Bool = false) {
        AISecureLogLevel.callerDesiredLogLevel = logLevel
        AISecureLogLevel.showTimestamps = timestamps
    }
    
    // MARK: - Service Factory
    
    @MainActor
    public static func openAIService(
        serviceURL: String,
        backendURL: String
    ) throws -> OpenAIService {
        let deps = try createDependencies(serviceURL: serviceURL, backendURL: backendURL)
        return OpenAIService(
            configuration: deps.configuration,
            requestBuilder: deps.requestBuilder,
            urlSession: deps.urlSession,
            deviceAuthenticator: deps.authenticator
        )
    }
    
    @MainActor
    public static func anthropicService(
        serviceURL: String,
        backendURL: String
    ) throws -> AnthropicService {
        let deps = try createDependencies(serviceURL: serviceURL, backendURL: backendURL)
        return AnthropicService(
            configuration: deps.configuration,
            requestBuilder: deps.requestBuilder,
            urlSession: deps.urlSession,
            deviceAuthenticator: deps.authenticator
        )
    }
    
    @MainActor
    public static func geminiService(
        serviceURL: String,
        backendURL: String
    ) throws -> GeminiService {
        let deps = try createDependencies(serviceURL: serviceURL, backendURL: backendURL)
        return GeminiService(
            configuration: deps.configuration,
            requestBuilder: deps.requestBuilder,
            urlSession: deps.urlSession,
            deviceAuthenticator: deps.authenticator
        )
    }
    
    @MainActor
    public static func grokService(
        serviceURL: String,
        backendURL: String
    ) throws -> GrokService {
        let deps = try createDependencies(serviceURL: serviceURL, backendURL: backendURL)
        return GrokService(
            configuration: deps.configuration,
            requestBuilder: deps.requestBuilder,
            urlSession: deps.urlSession,
            deviceAuthenticator: deps.authenticator
        )
    }
    
    // MARK: - Private
    
    private struct ServiceDependencies {
        let configuration: AISecureConfiguration
        let requestBuilder: AISecureRequestBuilder
        let urlSession: URLSession
        let authenticator: AISecureDeviceAuthenticator
    }
    
    @MainActor
    private static func createDependencies(
        serviceURL: String,
        backendURL: String
    ) throws -> ServiceDependencies {
        guard let backendURLParsed = URL(string: backendURL) else {
            throw AISecureError.invalidConfiguration("Invalid backend URL: \(backendURL)")
        }
        
        let deviceFingerprint = DeviceIdentifier.get()
        let urlSession = createURLSession()
        let storage = AISecureStorage()
        
        let authenticator = AISecureDeviceAuthenticator(
            backendURL: backendURLParsed,
            serviceURL: serviceURL,
            deviceFingerprint: deviceFingerprint,
            urlSession: urlSession,
            storage: storage
        )
        
        let configuration = AISecureConfiguration(
            backendURL: backendURLParsed,
            deviceFingerprint: deviceFingerprint,
            serviceURL: serviceURL
        )
        
        let requestBuilder = AISecureDefaultRequestBuilder(configuration: configuration)
        
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
