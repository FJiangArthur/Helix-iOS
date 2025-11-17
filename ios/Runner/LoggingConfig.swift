import Foundation

/// Centralized logging configuration for Helix iOS app
/// This file provides a single place to configure logging behavior across the entire application
class LoggingConfig {

    /// Configure logging for the entire application
    /// Call this method early in the app lifecycle (e.g., in AppDelegate)
    static func configure(for environment: Environment = .development) {
        switch environment {
        case .development:
            configureDevelopment()
        case .staging:
            configureStaging()
        case .production:
            configureProduction()
        }
    }

    /// Development environment configuration - verbose logging
    private static func configureDevelopment() {
        // HelixLogger.configuration.enableConsoleLogging = true
        // HelixLogger.configuration.enableStructuredLogging = true
        // HelixLogger.configuration.enableOSLog = true
        // HelixLogger.configuration.minimumLogLevel = .debug
        // HelixLogger.configuration.enablePIIRedaction = false  // Disable for easier debugging
        // HelixLogger.configuration.correlationIdEnabled = true

        // HelixLogger.info("Logging configured for DEVELOPMENT environment", category: .lifecycle)
    }

    /// Staging environment configuration - moderate logging
    private static func configureStaging() {
        // HelixLogger.configuration.enableConsoleLogging = true
        // HelixLogger.configuration.enableStructuredLogging = true
        // HelixLogger.configuration.enableOSLog = true
        // HelixLogger.configuration.minimumLogLevel = .info
        // HelixLogger.configuration.enablePIIRedaction = true
        // HelixLogger.configuration.correlationIdEnabled = true

        // HelixLogger.info("Logging configured for STAGING environment", category: .lifecycle)
    }

    /// Production environment configuration - minimal logging with PII protection
    private static func configureProduction() {
        // HelixLogger.configuration.enableConsoleLogging = false  // Reduce noise in production
        // HelixLogger.configuration.enableStructuredLogging = true
        // HelixLogger.configuration.enableOSLog = true
        // HelixLogger.configuration.minimumLogLevel = .warning  // Only warnings and above
        // HelixLogger.configuration.enablePIIRedaction = true   // Always protect PII in production
        // HelixLogger.configuration.correlationIdEnabled = true

        // HelixLogger.info("Logging configured for PRODUCTION environment", category: .lifecycle)
    }

    /// Update log level at runtime
    static func setLogLevel(_ level: LogLevel) {
        // HelixLogger.configuration.minimumLogLevel = level
        // HelixLogger.info("Log level changed to \(level.rawValue)", category: .lifecycle)
    }

    /// Enable or disable PII redaction at runtime
    static func setPIIRedaction(enabled: Bool) {
        // HelixLogger.configuration.enablePIIRedaction = enabled
        // HelixLogger.warning("PII redaction \(enabled ? "enabled" : "disabled")", category: .lifecycle)
    }

    /// Environment types
    enum Environment {
        case development
        case staging
        case production

        /// Automatically detect environment based on build configuration
        static var current: Environment {
            #if DEBUG
            return .development
            #elseif STAGING
            return .staging
            #else
            return .production
            #endif
        }
    }
}

// MARK: - Configuration Presets

extension LoggingConfig {
    /// Enable verbose audio debugging
    static func enableAudioDebugMode() {
        // HelixLogger.configuration.minimumLogLevel = .debug
        // HelixLogger.audio("Audio debug mode enabled", level: .info)
    }

    /// Enable verbose bluetooth debugging
    static func enableBluetoothDebugMode() {
        // HelixLogger.configuration.minimumLogLevel = .debug
        // HelixLogger.bluetooth("Bluetooth debug mode enabled", level: .info)
    }

    /// Disable all logging (useful for testing)
    static func disableAllLogging() {
        // HelixLogger.configuration.enableConsoleLogging = false
        // HelixLogger.configuration.enableStructuredLogging = false
        // HelixLogger.configuration.enableOSLog = false
    }

    /// Reset to default configuration
    static func resetToDefaults() {
        configure(for: .current)
    }
}

// MARK: - Performance Monitoring Configuration

extension LoggingConfig {
    /// Configure performance monitoring thresholds
    struct PerformanceThresholds {
        /// Threshold for audio processing (milliseconds)
        static let audioProcessing: TimeInterval = 0.050  // 50ms

        /// Threshold for bluetooth operations (milliseconds)
        static let bluetoothOperation: TimeInterval = 0.100  // 100ms

        /// Threshold for speech recognition (milliseconds)
        static let speechRecognition: TimeInterval = 0.200  // 200ms

        /// Log performance warning if duration exceeds threshold
        static func checkThreshold(operation: String, duration: TimeInterval, threshold: TimeInterval, category: LogCategory) {
            if duration > threshold {
                // HelixLogger.warning(
                //     "Performance threshold exceeded for \(operation)",
                //     category: category,
                //     metadata: [
                //         "duration_ms": String(format: "%.2f", duration * 1000),
                //         "threshold_ms": String(format: "%.2f", threshold * 1000)
                //     ]
                // )
            }
        }
    }
}
