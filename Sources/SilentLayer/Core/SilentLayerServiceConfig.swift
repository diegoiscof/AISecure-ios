//
//  SilentLayerServiceConfig.swift
//  SilentLayer
//
//  Created by Diego Francisco Oruna Cabrera on 22/12/25.
//

import Foundation

public struct SilentLayerServiceConfig: Sendable {
    public let provider: String
    public let serviceURL: String
    public let partialKey: String

    /// Extracts serviceId from the serviceURL
    /// Example: "https://api.gateway.com/openai-abc123/..." -> "abc123"
    public var serviceId: String {
        guard let url = URL(string: serviceURL),
              let firstComponent = url.pathComponents.dropFirst().first else {
            return ""
        }

        // Extract serviceId from format: {provider}-{serviceId}
        let components = firstComponent.split(separator: "-")
        if components.count >= 2 {
            return String(components.dropFirst().joined(separator: "-"))
        }

        return ""
    }

    /// Creates a service configuration
    ///
    /// - Parameters:
    ///   - provider: The AI provider (e.g., "openai", "anthropic", "google")
    ///   - serviceURL: The full service URL
    ///   - partialKey: The partial API key from the backend
    ///
    /// - Throws: SilentLayerError if the configuration is invalid
    public init(
        provider: String,
        serviceURL: String,
        partialKey: String
    ) throws {
        guard !provider.isEmpty else {
            throw SilentLayerError.invalidConfiguration("Provider cannot be empty")
        }
        guard !serviceURL.isEmpty else {
            throw SilentLayerError.invalidConfiguration("Service URL cannot be empty")
        }
        guard !partialKey.isEmpty else {
            throw SilentLayerError.invalidConfiguration("Partial key cannot be empty")
        }

        self.provider = provider
        self.serviceURL = serviceURL
        self.partialKey = partialKey
    }
}
