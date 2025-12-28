//
//  SilentLayerLogger.swift
//  SilentLayer
//
//  Created by Diego Francisco Oruna Cabrera on 22/12/25.
//

import OSLog

// MARK: - Log Level

/// Log levels for SilentLayer SDK
///
/// Set the desired log level via `SilentLayer.configure(logLevel:)`.
/// Only messages at or above the configured level will be displayed.
public enum SilentLayerLogLevel: Int, Comparable, Sendable {
    /// Detailed debugging information
    case debug = 0
    /// General informational messages
    case info = 1
    /// Potential issues that aren't errors
    case warning = 2
    /// Errors that don't prevent operation
    case error = 3
    /// Critical failures
    case critical = 4
    /// No logging
    case none = 5
    
    public static func < (lhs: SilentLayerLogLevel, rhs: SilentLayerLogLevel) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

// MARK: - Thread-Safe Configuration

/// Thread-safe storage for logger configuration
private final class LoggerConfiguration: @unchecked Sendable {
    private let queue = DispatchQueue(label: "com.aisecure.logger.config", attributes: .concurrent)
    
    private var _logLevel: SilentLayerLogLevel = .warning
    private var _showTimestamps: Bool = false
    
    var logLevel: SilentLayerLogLevel {
        get { queue.sync { _logLevel } }
        set { queue.async(flags: .barrier) { self._logLevel = newValue } }
    }
    
    var showTimestamps: Bool {
        get { queue.sync { _showTimestamps } }
        set { queue.async(flags: .barrier) { self._showTimestamps = newValue } }
    }
}

private let loggerConfig = LoggerConfiguration()

// MARK: - Public Configuration Access

extension SilentLayerLogLevel {
    /// The current log level threshold
    public static var callerDesiredLogLevel: SilentLayerLogLevel {
        get { loggerConfig.logLevel }
        set { loggerConfig.logLevel = newValue }
    }
    
    /// Whether to include timestamps in log output
    public static var showTimestamps: Bool {
        get { loggerConfig.showTimestamps }
        set { loggerConfig.showTimestamps = newValue }
    }
}

// MARK: - Logger Implementation

/// The underlying OSLog logger
private let aisecureLogger = Logger(
    subsystem: Bundle.main.bundleIdentifier ?? "com.aisecure.sdk",
    category: "SilentLayer"
)

/// Custom logger that adds optional timestamps and respects log level filtering
internal struct SilentLayerTimestampLogger {
    private let logger: Logger
    
    init(logger: Logger) {
        self.logger = logger
    }
    
    func debug(_ message: @autoclosure () -> String) {
        log(message(), level: .debug)
    }
    
    func info(_ message: @autoclosure () -> String) {
        log(message(), level: .info)
    }
    
    func warning(_ message: @autoclosure () -> String) {
        log(message(), level: .warning)
    }
    
    func error(_ message: @autoclosure () -> String) {
        log(message(), level: .error)
    }
    
    func critical(_ message: @autoclosure () -> String) {
        log(message(), level: .critical)
    }
    
    private func log(_ message: String, level: SilentLayerLogLevel) {
        let finalMessage = SilentLayerLogLevel.showTimestamps
            ? "[\(Self.timestamp)] \(message)"
            : message
        
        switch level {
        case .debug:
            logger.debug("\(finalMessage, privacy: .public)")
        case .info:
            logger.info("\(finalMessage, privacy: .public)")
        case .warning:
            logger.warning("\(finalMessage, privacy: .public)")
        case .error:
            logger.error("\(finalMessage, privacy: .public)")
        case .critical:
            logger.critical("\(finalMessage, privacy: .public)")
        case .none:
            break
        }
    }
    
    /// High-precision timestamp string (HH:mm:ss.SSS)
    private static var timestamp: String {
        let now = Date()
        let calendar = Calendar.current
        let components = calendar.dateComponents([.hour, .minute, .second], from: now)
        let milliseconds = Int(now.timeIntervalSince1970 * 1000) % 1000
        
        return String(
            format: "%02d:%02d:%02d.%03d",
            components.hour ?? 0,
            components.minute ?? 0,
            components.second ?? 0,
            milliseconds
        )
    }
}

// MARK: - Log Function

/// Returns a logger if the specified level meets the threshold, nil otherwise
///
/// Usage:
/// ```swift
/// logIf(.debug)?.debug("Detailed info")
/// logIf(.error)?.error("Something went wrong")
/// ```
@inline(__always)
internal func logIf(_ logLevel: SilentLayerLogLevel) -> SilentLayerTimestampLogger? {
    guard logLevel >= SilentLayerLogLevel.callerDesiredLogLevel else {
        return nil
    }
    return SilentLayerTimestampLogger(logger: aisecureLogger)
}
