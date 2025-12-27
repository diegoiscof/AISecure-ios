//
//  AISecureRequestBuilder.swift
//  AISecure
//
//  Created by Diego Francisco Oruna Cabrera on 22/12/25.
//

import Foundation
import CryptoKit

public protocol AISecureRequestBuilder: Sendable {
    func buildRequest(
        endpoint: String,
        body: Data,
        session: AISecureSession,
        service: AISecureServiceConfig
    ) -> URLRequest
}

public struct AISecureDefaultRequestBuilder: AISecureRequestBuilder, Sendable {
    private let configuration: AISecureConfiguration

    public init(configuration: AISecureConfiguration) {
        self.configuration = configuration
    }

    public func buildRequest(
        endpoint: String,
        body: Data,
        session: AISecureSession,
        service: AISecureServiceConfig
    ) -> URLRequest {
        let urlString = service.serviceURL + endpoint

        guard let url = URL(string: urlString) else {
            fatalError("Invalid service URL: \(urlString)")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = body
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // Sign the request with HMAC
        sign(
            request: &request,
            body: body,
            service: service,
            session: session,
            endpoint: endpoint
        )

        return request
    }

    private func sign(
        request: inout URLRequest,
        body: Data,
        service: AISecureServiceConfig,
        session: AISecureSession,
        endpoint: String
    ) {
        let timestamp = String(Int(Date().timeIntervalSince1970))

        request.setValue(service.partialKey, forHTTPHeaderField: "x-partial-key")
        request.setValue(session.sessionToken, forHTTPHeaderField: "x-session-token")
        request.setValue(timestamp, forHTTPHeaderField: "x-timestamp")
        request.setValue(configuration.deviceFingerprint, forHTTPHeaderField: "x-device-fingerprint")
        request.setValue(service.provider, forHTTPHeaderField: "x-provider")
        if service.provider == "anthropic" {
            request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        }

        let normalizedEndpoint = endpoint.hasPrefix("/") ? endpoint : "/" + endpoint

        let bodyBase64 = body.base64EncodedString()
        // 🔒 SECURITY: Include provider + serviceId to bind signature to specific service
        let message = "\(timestamp):\(service.provider):\(service.serviceId):\(normalizedEndpoint):\(bodyBase64):\(session.sessionToken)"

        // ✅ MUST match Lambda: raw sessionToken as HMAC key
        let key = SymmetricKey(data: Data(session.sessionToken.utf8))

        let signature = HMAC<SHA256>.authenticationCode(
            for: Data(message.utf8),
            using: key
        )

        request.setValue(
            Data(signature).base64EncodedString(),
            forHTTPHeaderField: "x-signature"
        )

        logIf(.debug)?.debug("➡️ Request to \(endpoint)")
    }
}
