//
//  AISecureDeviceAuthenticator.swift
//  AISecure
//
//  Created by Diego Francisco Oruna Cabrera on 23/12/25.
//

import Foundation

// MARK: - Credentials Container

/// Contains all credentials needed to make authenticated requests
/// Derived from a single JWT, ensuring consistency
public struct AISecureCredentials: Sendable {
    public let service: AISecureServiceConfig
    public let session: AISecureSession
    
    /// Check if credentials are expired
    public var isExpired: Bool {
        session.isExpired
    }
}

// MARK: - Device Authenticator

/// Handles device authentication and credential management
///
/// This is the single source of truth for authentication state.
/// JWT and session are tightly coupled (created together on backend),
/// so this class manages them as a unit.
///
/// Flow:
/// 1. App calls `getCredentials()`
/// 2. Returns cached credentials if valid
/// 3. Otherwise fetches new JWT from `/auth/device`
/// 4. Extracts credentials from JWT payload
/// 5. Caches and returns credentials
@AISecureActor
public final class AISecureDeviceAuthenticator: Sendable {
    
    // MARK: - Configuration
    
    private let backendURL: URL
    private let serviceURL: String
    private let deviceFingerprint: String
    private let urlSession: URLSession
    private let storage: AISecureStorage
    
    // MARK: - Cached State
    
    private var cachedJWT: DeviceJWT?
    private var cachedCredentials: AISecureCredentials?
    
    /// In-flight authentication request (prevents duplicate calls)
    private var pendingAuthentication: Task<DeviceJWT, Error>?
    
    // MARK: - Initialization
    
    nonisolated public init(
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
    
    // MARK: - Public API
    
    /// Get valid credentials for making authenticated requests
    ///
    /// This is the main entry point for the retry mechanism.
    /// Returns cached credentials if valid, otherwise fetches fresh ones.
    ///
    /// - Parameter forceRefresh: Skip cache and fetch fresh credentials
    /// - Returns: Valid credentials containing service config and session
    /// - Throws: AISecureError if authentication fails
    public func getCredentials(forceRefresh: Bool = false) async throws -> AISecureCredentials {
        // Fast path: return cached credentials if valid and not forcing refresh
        if !forceRefresh, let cached = cachedCredentials, !cached.isExpired {
            logIf(.debug)?.debug("✅ Using cached credentials")
            return cached
        }
        
        // Get valid JWT (from cache, storage, or network)
        let jwt = try await getValidJWT(forceRefresh: forceRefresh)
        
        // Decode payload and build credentials
        let payload = try jwt.decodePayload()
        let credentials = try buildCredentials(from: payload)
        
        // Cache for future use
        cachedCredentials = credentials
        
        logIf(.debug)?.debug("✅ Credentials ready (provider: \(credentials.service.provider))")
        return credentials
    }
    
    /// Invalidate all credentials
    ///
    /// Called by retry mechanism when server returns 401.
    /// Clears both JWT and derived session since they're coupled.
    public func invalidateCredentials() {
        logIf(.info)?.info("🔄 Invalidating credentials")
        
        cachedJWT = nil
        cachedCredentials = nil
        pendingAuthentication?.cancel()
        pendingAuthentication = nil
        
        // Clear persisted data
        storage.deleteJWT(for: serviceURL)
        storage.deleteSession(for: serviceURL)
    }
    
    /// Check if we have valid (non-expired) credentials
    ///
    /// Useful for UI to show login state without triggering network calls
    public var hasValidCredentials: Bool {
        if let cached = cachedCredentials, !cached.isExpired {
            return true
        }
        // Check storage
        if let stored = try? storage.loadJWT(for: serviceURL), !stored.isExpired {
            return true
        }
        return false
    }
    
    /// Get time until credentials expire (in seconds)
    ///
    /// Returns nil if no valid credentials exist
    public var timeUntilExpiry: TimeInterval? {
        guard let credentials = cachedCredentials, !credentials.isExpired else {
            return nil
        }
        let expiryDate = Date(timeIntervalSince1970: Double(credentials.session.expiresAt) / 1000)
        return expiryDate.timeIntervalSinceNow
    }
    
    // MARK: - Private: JWT Management
    
    /// Get a valid JWT, fetching from network if needed
    private func getValidJWT(forceRefresh: Bool) async throws -> DeviceJWT {
        // Check memory cache
        if !forceRefresh, let cached = cachedJWT, !cached.isExpired {
            return cached
        }
        
        // Check persistent storage
        if !forceRefresh, let stored = try? storage.loadJWT(for: serviceURL), !stored.isExpired {
            cachedJWT = stored
            return stored
        }
        
        // Need to fetch from network
        return try await fetchJWT()
    }
    
    /// Fetch JWT from backend, coalescing concurrent requests
    private func fetchJWT() async throws -> DeviceJWT {
        // If there's already a request in flight, wait for it
        if let pending = pendingAuthentication {
            logIf(.debug)?.debug("⏳ Waiting for in-flight authentication")
            return try await pending.value
        }
        
        // Start new authentication request
        let task = Task<DeviceJWT, Error> {
            try await performAuthentication()
        }
        
        pendingAuthentication = task
        
        do {
            let jwt = try await task.value
            pendingAuthentication = nil
            return jwt
        } catch {
            pendingAuthentication = nil
            throw error
        }
    }
    
    /// Perform the actual authentication request
    private func performAuthentication() async throws -> DeviceJWT {
        let endpoint = backendURL.appendingPathComponent("/auth/device")
        
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "serviceURL": serviceURL,
            "deviceFingerprint": deviceFingerprint
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        logIf(.debug)?.debug("🔐 Authenticating device...")
        
        let (data, response) = try await urlSession.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AISecureError.invalidResponse
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            let errorBody = HTTPErrorBody(from: data)
            logIf(.error)?.error("❌ Authentication failed: HTTP \(httpResponse.statusCode)")
            throw AISecureError.httpError(status: httpResponse.statusCode, body: errorBody)
        }
        
        let jwt = try JSONDecoder().decode(DeviceJWT.self, from: data)
        
        // Cache in memory and storage
        cachedJWT = jwt
        try? storage.saveJWT(jwt, for: serviceURL)
        
        logIf(.info)?.info("✅ Device authenticated successfully")
        return jwt
    }
    
    // MARK: - Private: Credential Building
    
    /// Build credentials from JWT payload
    private func buildCredentials(from payload: DeviceJWT.Payload) throws -> AISecureCredentials {
        let service = try AISecureServiceConfig(
            provider: payload.provider,
            serviceURL: serviceURL,
            partialKey: payload.partialKey
        )
        
        let session = AISecureSession(
            sessionToken: payload.sessionToken,
            expiresAt: payload.exp * 1000,  // Convert seconds to milliseconds
            provider: payload.provider,
            serviceURL: serviceURL
        )
        
        return AISecureCredentials(service: service, session: session)
    }
}

// MARK: - Backward Compatibility (Deprecated)

extension AISecureDeviceAuthenticator {
    
    /// Get valid JWT directly
    /// - Note: Prefer `getCredentials()` instead
    @available(*, deprecated, message: "Use getCredentials() instead")
    public func getValidJWT() async throws -> DeviceJWT {
        try await getValidJWT(forceRefresh: false)
    }
    
    /// Invalidate JWT only
    /// - Note: Prefer `invalidateCredentials()` instead
    @available(*, deprecated, message: "Use invalidateCredentials() instead")
    public func invalidateJWT() {
        invalidateCredentials()
    }
}
