//
//  AISecureDeviceAuthenticator.swift
//  AISecure
//
//  Created by AISecure on 23/12/25.
//

import Foundation

/// Handles device authentication with backend to obtain JWT credentials
@AISecureActor
public class AISecureDeviceAuthenticator: Sendable {
    private let backendURL: URL
    private let serviceURL: String
    private let deviceFingerprint: String
    private let urlSession: URLSession
    private let storage: AISecureStorage

    private var cachedJWT: DeviceJWT?

    nonisolated init(
        backendURL: URL,
        serviceURL: String,
        deviceFingerprint: String,
        urlSession: URLSession,
        storage: AISecureStorage
    ) {
        self.backendURL = backendURL
        self.serviceURL = serviceURL
        self.deviceFingerprint = deviceFingerprint
        self.urlSession = urlSession
        self.storage = storage
    }

    /// Get valid JWT credentials (from cache, storage, or backend)
    public func getValidJWT(forceRefresh: Bool = false) async throws -> DeviceJWT {
        // Check cache first
        if !forceRefresh {
            if let cached = cachedJWT, !cached.isExpired {
                return cached
            }

            // Check storage
            if let stored = try? storage.loadJWT(for: serviceURL), !stored.isExpired {
                cachedJWT = stored
                return stored
            }
        }

        // Authenticate with backend
        let jwt = try await authenticateDevice()
        cachedJWT = jwt
        try? storage.saveJWT(jwt, for: serviceURL)
        return jwt
    }

    /// Invalidate cached JWT (called when backend returns 401)
    public func invalidateJWT() {
        cachedJWT = nil
        storage.deleteJWT(for: serviceURL)
    }

    private func authenticateDevice() async throws -> DeviceJWT {
        let endpoint = backendURL.appendingPathComponent("api/auth/device")

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: String] = [
            "serviceURL": serviceURL,
            "deviceFingerprint": deviceFingerprint
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await urlSession.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AISecureError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let errorBody = try? JSONSerialization.jsonObject(with: data)
            logIf(.error)?.error("Device auth failed: \(httpResponse.statusCode)")
            throw AISecureError.httpError(status: httpResponse.statusCode, body: errorBody ?? [:])
        }

        return try JSONDecoder().decode(DeviceJWT.self, from: data)
    }
}
