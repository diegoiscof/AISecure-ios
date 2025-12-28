//
//  SilentLayerSession.swift
//  SilentLayer
//
//  Created by Diego Francisco Oruna Cabrera on 22/12/25.
//

import Foundation

public struct SilentLayerSession: Codable, Sendable {
    public let sessionToken: String
    public let expiresAt: Int
    public let provider: String
    public let serviceURL: String

    public var isExpired: Bool {
        return Date().timeIntervalSince1970 > Double(expiresAt)
    }

    public init(sessionToken: String, expiresAt: Int, provider: String, serviceURL: String) {
        self.sessionToken = sessionToken
        self.expiresAt = expiresAt
        self.provider = provider
        self.serviceURL = serviceURL
    }
}
