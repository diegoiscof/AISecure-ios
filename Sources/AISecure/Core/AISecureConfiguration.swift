//
//  AISecureConfiguration.swift
//  AISecure
//

import Foundation

/// Configuration for AISecure SDK
public struct AISecureConfiguration: Sendable {
    public let backendURL: URL
    public let deviceFingerprint: String
    public let serviceURL: String
    
    public init(
        backendURL: URL,
        deviceFingerprint: String,
        serviceURL: String
    ) {
        self.backendURL = backendURL
        self.deviceFingerprint = deviceFingerprint
        self.serviceURL = serviceURL
    }
}
