//
//  DeviceMetadata.swift
//  SilentLayer
//
//  Created by Diego Francisco Oruna Cabrera on 22/12/25.
//

import Foundation

#if canImport(UIKit)
import UIKit
#endif

/// Device and app metadata for debugging and analytics
///
/// This metadata can be sent with requests for server-side logging,
/// debugging, or analytics purposes.
public struct DeviceMetadata: Sendable {
    
    /// Bundle identifier of the host app
    public let bundleID: String
    
    /// Version of the host app
    public let appVersion: String
    
    /// Version of the SilentLayer SDK
    public let sdkVersion: String
    
    /// Operating system name (iOS, macOS, etc.)
    public let systemName: String
    
    /// Operating system version
    public let osVersion: String
    
    /// Device model (iPhone, iPad, Mac, etc.)
    public let deviceModel: String
    
    /// Timestamp when metadata was captured
    public let timestamp: Date
    
    // MARK: - Initialization
    
    /// Creates metadata with current device/app information
    @MainActor
    public static func current() -> DeviceMetadata {
        #if canImport(UIKit)
        return DeviceMetadata(
            bundleID: Bundle.main.bundleIdentifier ?? "unknown",
            appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown",
            sdkVersion: SilentLayer.sdkVersion,
            systemName: UIDevice.current.systemName,
            osVersion: UIDevice.current.systemVersion,
            deviceModel: UIDevice.current.model,
            timestamp: Date()
        )
        #else
        return DeviceMetadata(
            bundleID: Bundle.main.bundleIdentifier ?? "unknown",
            appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown",
            sdkVersion: SilentLayer.sdkVersion,
            systemName: "macOS",
            osVersion: ProcessInfo.processInfo.operatingSystemVersionString,
            deviceModel: "Mac",
            timestamp: Date()
        )
        #endif
    }
    
    // MARK: - Serialization
    
    /// Returns metadata as a dictionary for JSON serialization
    public var dictionary: [String: String] {
        [
            "bundle_id": bundleID,
            "app_version": appVersion,
            "sdk_version": sdkVersion,
            "system_name": systemName,
            "os_version": osVersion,
            "device_model": deviceModel,
            "timestamp": ISO8601DateFormatter().string(from: timestamp)
        ]
    }
    
    /// Returns metadata as a pipe-separated string (legacy format)
    ///
    /// Format: `version|bundleID|appVersion|sdkVersion|timestamp|systemName|osVersion|deviceModel`
    public var legacyString: String {
        let components = [
            "1", // format version
            bundleID,
            appVersion,
            sdkVersion,
            String(Int(timestamp.timeIntervalSince1970)),
            systemName,
            osVersion,
            deviceModel
        ]
        return components.joined(separator: "|")
    }
    
    /// Returns metadata as an HTTP header value
    public var headerValue: String {
        // Base64 encode the JSON for safe header transmission
        guard let data = try? JSONSerialization.data(withJSONObject: dictionary),
              let base64 = data.base64EncodedString().addingPercentEncoding(withAllowedCharacters: .urlSafe) else {
            return legacyString
        }
        return base64
    }
}

// MARK: - CharacterSet Extension

private extension CharacterSet {
    static let urlSafe = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~")
}
