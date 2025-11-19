import Foundation
import os.log

// MARK: - Log Level
public enum LogLevel: String, Codable {
    case debug = "DEBUG"
    case info = "INFO"
    case warning = "WARNING"
    case error = "ERROR"
    case critical = "CRITICAL"

    var osLogType: OSLogType {
        switch self {
        case .debug: return .debug
        case .info: return .info
        case .warning: return .default
        case .error: return .error
        case .critical: return .fault
        }
    }

    var emoji: String {
        switch self {
        case .debug: return "🔍"
        case .info: return "ℹ️"
        case .warning: return "⚠️"
        case .error: return "❌"
        case .critical: return "🔥"
        }
    }
}

// MARK: - Log Category
public enum LogCategory: String, Codable {
    case audio = "Audio"
    case bluetooth = "Bluetooth"
    case speech = "Speech"
    case ui = "UI"
    case network = "Network"
    case lifecycle = "Lifecycle"
    case recording = "Recording"
    case general = "General"

    var osLog: OSLog {
        return OSLog(subsystem: HelixLogger.subsystem, category: self.rawValue)
    }
}

// MARK: - Log Entry
public struct LogEntry: Codable {
    let timestamp: String
    let level: LogLevel
    let category: LogCategory
    let message: String
    let correlationId: String?
    let context: LogContext
    let metadata: [String: String]?

    struct LogContext: Codable {
        let file: String
        let function: String
        let line: Int
    }
}

// MARK: - Logger Configuration
public struct LoggerConfiguration {
    var enableConsoleLogging: Bool = true
    var enableStructuredLogging: Bool = true
    var enableOSLog: Bool = true
    var minimumLogLevel: LogLevel = .debug
    var enablePIIRedaction: Bool = true
    var correlationIdEnabled: Bool = true

    static var shared = LoggerConfiguration()
}

// MARK: - PII Redactor
public class PIIRedactor {
    private static let emailPattern = "[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}"
    private static let phonePattern = "\\+?[1-9]\\d{1,14}"
    private static let uuidPattern = "[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}"
    private static let ipAddressPattern = "\\b(?:[0-9]{1,3}\\.){3}[0-9]{1,3}\\b"

    static func redact(_ message: String) -> String {
        var redacted = message

        // Redact email addresses
        redacted = redacted.replacingOccurrences(
            of: emailPattern,
            with: "[EMAIL_REDACTED]",
            options: .regularExpression
        )

        // Redact phone numbers
        redacted = redacted.replacingOccurrences(
            of: phonePattern,
            with: "[PHONE_REDACTED]",
            options: .regularExpression
        )

        // Partially redact UUIDs (keep first 8 chars for debugging)
        let uuidRegex = try? NSRegularExpression(pattern: uuidPattern)
        if let regex = uuidRegex {
            let matches = regex.matches(in: redacted, range: NSRange(redacted.startIndex..., in: redacted))
            for match in matches.reversed() {
                if let range = Range(match.range, in: redacted) {
                    let uuid = String(redacted[range])
                    let prefix = String(uuid.prefix(8))
                    redacted.replaceSubrange(range, with: "\(prefix)-[REDACTED]")
                }
            }
        }

        // Redact IP addresses
        redacted = redacted.replacingOccurrences(
            of: ipAddressPattern,
            with: "[IP_REDACTED]",
            options: .regularExpression
        )

        return redacted
    }
}

// MARK: - Helix Logger
public class HelixLogger {
    static let subsystem = "com.helix.ios"
    private static var correlationIdStorage: String?

    // MARK: - Configuration
    public static var configuration = LoggerConfiguration.shared

    // MARK: - Correlation ID Management
    public static func setCorrelationId(_ id: String?) {
        correlationIdStorage = id
    }

    public static func generateCorrelationId() -> String {
        let uuid = UUID().uuidString
        setCorrelationId(uuid)
        return uuid
    }

    public static func getCorrelationId() -> String? {
        return correlationIdStorage
    }

    // MARK: - Main Logging Function
    private static func log(
        level: LogLevel,
        category: LogCategory,
        message: String,
        metadata: [String: String]? = nil,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        // Check minimum log level
        guard shouldLog(level: level) else { return }

        // Apply PII redaction if enabled
        let finalMessage = configuration.enablePIIRedaction ? PIIRedactor.redact(message) : message

        // Create log entry
        let fileName = (file as NSString).lastPathComponent
        let context = LogEntry.LogContext(file: fileName, function: function, line: line)

        let entry = LogEntry(
            timestamp: ISO8601DateFormatter().string(from: Date()),
            level: level,
            category: category,
            message: finalMessage,
            correlationId: configuration.correlationIdEnabled ? correlationIdStorage : nil,
            context: context,
            metadata: metadata
        )

        // Console logging (human-readable)
        if configuration.enableConsoleLogging {
            logToConsole(entry: entry)
        }

        // Structured logging (JSON)
        if configuration.enableStructuredLogging {
            logStructured(entry: entry)
        }

        // OS Log (system-level logging)
        if configuration.enableOSLog {
            logToOSLog(entry: entry, category: category, level: level, message: finalMessage)
        }
    }

    private static func shouldLog(level: LogLevel) -> Bool {
        let levels: [LogLevel] = [.debug, .info, .warning, .error, .critical]
        guard let currentIndex = levels.firstIndex(of: configuration.minimumLogLevel),
              let messageIndex = levels.firstIndex(of: level) else {
            return true
        }
        return messageIndex >= currentIndex
    }

    private static func logToConsole(entry: LogEntry) {
        let correlationInfo = entry.correlationId.map { " [CID:\($0.prefix(8))]" } ?? ""
        let metadataInfo = entry.metadata?.map { "\($0.key)=\($0.value)" }.joined(separator: ", ") ?? ""
        let metadataString = metadataInfo.isEmpty ? "" : " {\(metadataInfo)}"

        print("\(entry.level.emoji) [\(entry.level.rawValue)] [\(entry.category.rawValue)]\(correlationInfo) \(entry.message)\(metadataString) (\(entry.context.file):\(entry.context.line))")
    }

    private static func logStructured(entry: LogEntry) {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]

        if let jsonData = try? encoder.encode(entry),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            print("[STRUCTURED] \(jsonString)")
        }
    }

    private static func logToOSLog(entry: LogEntry, category: LogCategory, level: LogLevel, message: String) {
        if #available(iOS 14.0, *) {
            let logger = Logger(subsystem: subsystem, category: category.rawValue)
            let logMessage = "\(message) (\(entry.context.file):\(entry.context.line))"

            switch level {
            case .debug:
                logger.debug("\(logMessage)")
            case .info:
                logger.info("\(logMessage)")
            case .warning:
                logger.warning("\(logMessage)")
            case .error:
                logger.error("\(logMessage)")
            case .critical:
                logger.critical("\(logMessage)")
            }
        } else {
            os_log("%{public}@", log: category.osLog, type: level.osLogType, message)
        }
    }

    // MARK: - Public API - Log Level Methods

    public static func debug(
        _ message: String,
        category: LogCategory = .general,
        metadata: [String: String]? = nil,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        log(level: .debug, category: category, message: message, metadata: metadata, file: file, function: function, line: line)
    }

    public static func info(
        _ message: String,
        category: LogCategory = .general,
        metadata: [String: String]? = nil,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        log(level: .info, category: category, message: message, metadata: metadata, file: file, function: function, line: line)
    }

    public static func warning(
        _ message: String,
        category: LogCategory = .general,
        metadata: [String: String]? = nil,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        log(level: .warning, category: category, message: message, metadata: metadata, file: file, function: function, line: line)
    }

    public static func error(
        _ message: String,
        category: LogCategory = .general,
        metadata: [String: String]? = nil,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        log(level: .error, category: category, message: message, metadata: metadata, file: file, function: function, line: line)
    }

    public static func critical(
        _ message: String,
        category: LogCategory = .general,
        metadata: [String: String]? = nil,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        log(level: .critical, category: category, message: message, metadata: metadata, file: file, function: function, line: line)
    }

    // MARK: - Convenience Methods

    /// Log with automatic error extraction
    public static func error(
        _ message: String,
        error: Error,
        category: LogCategory = .general,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        let metadata = ["error": error.localizedDescription]
        log(level: .error, category: category, message: message, metadata: metadata, file: file, function: function, line: line)
    }

    /// Log audio-related messages
    public static func audio(
        _ message: String,
        level: LogLevel = .info,
        metadata: [String: String]? = nil,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        log(level: level, category: .audio, message: message, metadata: metadata, file: file, function: function, line: line)
    }

    /// Log bluetooth-related messages
    public static func bluetooth(
        _ message: String,
        level: LogLevel = .info,
        metadata: [String: String]? = nil,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        log(level: level, category: .bluetooth, message: message, metadata: metadata, file: file, function: function, line: line)
    }

    /// Log speech recognition messages
    public static func speech(
        _ message: String,
        level: LogLevel = .info,
        metadata: [String: String]? = nil,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        log(level: level, category: .speech, message: message, metadata: metadata, file: file, function: function, line: line)
    }
}

// MARK: - Logger Extensions for common use cases
extension HelixLogger {
    /// Log performance metrics
    public static func logPerformance(
        operation: String,
        duration: TimeInterval,
        category: LogCategory = .general,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        let metadata: [String: String] = [:]
        info("Performance: \(operation)", category: category, metadata: metadata, file: file, function: function, line: line)
    }

    /// Measure and log execution time
    public static func measure<T>(
        _ operation: String,
        category: LogCategory = .general,
        block: () throws -> T
    ) rethrows -> T {
        let start = Date()
        defer {
            let duration = Date().timeIntervalSince(start)
            logPerformance(operation: operation, duration: duration, category: category)
        }
        return try block()
    }
}
