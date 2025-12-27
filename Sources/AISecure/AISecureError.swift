//
//  AISecureError.swift
//  AISecure
//
//  Created by Diego Francisco Oruna Cabrera on 22/12/25.
//

import Foundation

// MARK: - Error Body

/// Structured HTTP error body from backend
public struct HTTPErrorBody: Sendable, CustomStringConvertible {
    public let code: String?
    public let message: String?
    public let raw: String?
    
    public init(code: String?, message: String?, raw: String?) {
        self.code = code
        self.message = message
        self.raw = raw
    }
    
    public init(from data: Data) {
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            self.code = json["code"] as? String
            self.message = json["message"] as? String ?? json["error"] as? String
            self.raw = nil
        } else {
            self.code = nil
            self.message = nil
            self.raw = String(data: data, encoding: .utf8)
        }
    }
    
    public var description: String {
        if let message = message {
            return code != nil ? "[\(code!)] \(message)" : message
        }
        return raw ?? "Unknown error"
    }
}

// MARK: - Rate Limit Info

/// Information about rate limiting from backend
public struct AISecureRateLimitInfo: Sendable {
    public let retryAfter: Int
    public let reason: String
    public let used: Int?
    public let limit: Int?
    public let tier: String?
    
    public init(from body: HTTPErrorBody, retryAfter: Int) {
        self.retryAfter = retryAfter
        self.reason = body.message ?? "Rate limit exceeded"
        // These would come from extended error body if backend provides them
        self.used = nil
        self.limit = nil
        self.tier = nil
    }
    
    public init(retryAfter: Int, reason: String, used: Int?, limit: Int?, tier: String?) {
        self.retryAfter = retryAfter
        self.reason = reason
        self.used = used
        self.limit = limit
        self.tier = tier
    }
}

// MARK: - Main Error Type

public enum AISecureError: Error, LocalizedError, Sendable {
    case invalidResponse
    case httpError(status: Int, body: HTTPErrorBody)
    case decodingError(String)
    case providerNotConfigured(String)
    case invalidConfiguration(String)
    case sessionExpired
    case networkError(String)
    case rateLimited(AISecureRateLimitInfo)
    case serviceUnavailable(retryAfter: Int, reason: String)
    case cancelled
    
    public var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Invalid response from server"
        case .httpError(let status, let body):
            return "HTTP \(status): \(body.description)"
        case .decodingError(let message):
            return "Failed to decode response: \(message)"
        case .providerNotConfigured(let provider):
            return "Provider not configured: \(provider)"
        case .invalidConfiguration(let message):
            return "Invalid configuration: \(message)"
        case .sessionExpired:
            return "Session expired"
        case .networkError(let message):
            return "Network error: \(message)"
        case .rateLimited(let info):
            return "Rate limited: \(info.reason). Retry after \(info.retryAfter)s"
        case .serviceUnavailable(let retryAfter, let reason):
            return "Service unavailable: \(reason). Retry after \(retryAfter)s"
        case .cancelled:
            return "Request was cancelled"
        }
    }
    
    /// Error code from backend (if available)
    public var errorCode: String? {
        if case .httpError(_, let body) = self {
            return body.code
        }
        return nil
    }
    
    /// Whether this error is recoverable by retrying
    public var isRetryable: Bool {
        switch self {
        case .rateLimited, .serviceUnavailable, .networkError:
            return true
        case .httpError(let status, _):
            return status >= 500 || status == 429
        default:
            return false
        }
    }
    
    /// Suggested retry delay in seconds (if applicable)
    public var retryAfter: Int? {
        switch self {
        case .rateLimited(let info):
            return info.retryAfter
        case .serviceUnavailable(let retryAfter, _):
            return retryAfter
        default:
            return nil
        }
    }
}
