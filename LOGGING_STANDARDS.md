# Logging Standards - Helix iOS

## Overview

This document defines the logging standards for the Helix iOS application. All services use the standardized `HelixLogger` utility for consistent, structured logging with built-in features like correlation IDs, PII redaction, and multiple output formats.

## Table of Contents

1. [Architecture](#architecture)
2. [Log Levels](#log-levels)
3. [Log Categories](#log-categories)
4. [Usage Guidelines](#usage-guidelines)
5. [Configuration](#configuration)
6. [Best Practices](#best-practices)
7. [Examples](#examples)
8. [PII Redaction](#pii-redaction)
9. [Correlation IDs](#correlation-ids)
10. [Performance Monitoring](#performance-monitoring)

---

## Architecture

The logging system consists of three main components:

1. **HelixLogger** (`HelixLogger.swift`) - Core logging utility
2. **LoggingConfig** (`LoggingConfig.swift`) - Centralized configuration
3. **Service Integration** - All services use HelixLogger for logging

### Key Features

- ✅ **Structured Logging**: JSON-formatted logs for easy parsing
- ✅ **Multiple Log Levels**: Debug, Info, Warning, Error, Critical
- ✅ **Category-based Logging**: Audio, Bluetooth, Speech, etc.
- ✅ **Correlation IDs**: Track related operations across services
- ✅ **PII Redaction**: Automatically redact sensitive information
- ✅ **OS Integration**: Uses native iOS Logger (iOS 14+) and OSLog
- ✅ **Contextual Information**: Automatic file, function, and line numbers
- ✅ **Environment-aware**: Different configurations for dev/staging/production

---

## Log Levels

The logging system supports five log levels, ordered by severity:

| Level    | When to Use | Example Use Cases |
|----------|-------------|-------------------|
| **DEBUG** | Detailed diagnostic information | Variable values, execution flow, detailed state |
| **INFO** | General informational messages | Service started, operation completed, configuration loaded |
| **WARNING** | Potentially harmful situations | Deprecated API usage, recoverable errors, performance issues |
| **ERROR** | Error events that might still allow the app to continue | Failed operations, caught exceptions, invalid data |
| **CRITICAL** | Severe errors that might cause app crash | Unrecoverable errors, critical resource failures |

### Log Level Filtering

The minimum log level can be configured per environment:
- **Development**: DEBUG and above
- **Staging**: INFO and above
- **Production**: WARNING and above

---

## Log Categories

Logs are organized by category to facilitate filtering and analysis:

| Category | Description | Use Cases |
|----------|-------------|-----------|
| **audio** | Audio-related operations | Audio session setup, recording, playback, permissions |
| **bluetooth** | Bluetooth operations | Device discovery, connection, data transfer, GATT operations |
| **speech** | Speech recognition | Recognition start/stop, transcription, language selection |
| **ui** | User interface events | View lifecycle, user interactions |
| **network** | Network operations | API calls, data synchronization |
| **lifecycle** | App lifecycle events | App start, background/foreground transitions |
| **recording** | Recording operations | Recording start/stop, file management |
| **general** | General-purpose logging | Default category for uncategorized logs |

---

## Usage Guidelines

### Basic Logging

```swift
// Simple info log
HelixLogger.info("User logged in successfully")

// Log with category
HelixLogger.info("Bluetooth device connected", category: .bluetooth)

// Log with metadata
HelixLogger.info("Audio session configured", category: .audio, metadata: [
    "sampleRate": "44100",
    "channels": "2"
])
```

### Level-specific Methods

```swift
// Debug
HelixLogger.debug("Processing data batch", category: .general)

// Info
HelixLogger.info("Operation completed successfully", category: .general)

// Warning
HelixLogger.warning("API rate limit approaching", category: .network)

// Error with exception
HelixLogger.error("Failed to connect to device", error: error, category: .bluetooth)

// Critical
HelixLogger.critical("Database corruption detected", category: .general)
```

### Category-specific Convenience Methods

```swift
// Audio logging
HelixLogger.audio("Audio session started", level: .info)
HelixLogger.audio("Microphone permission denied", level: .error)

// Bluetooth logging
HelixLogger.bluetooth("Scanning for devices", level: .info)
HelixLogger.bluetooth("Connection failed", level: .error)

// Speech logging
HelixLogger.speech("Recognition started", level: .info, metadata: [
    "language": "en-US"
])
```

---

## Configuration

### Initial Setup

Configure logging early in the app lifecycle (in `AppDelegate`):

```swift
override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
) -> Bool {
    // Configure logging for the current environment
    LoggingConfig.configure(for: .current)

    // Rest of your app initialization...
    return true
}
```

### Environment Configuration

The logging configuration automatically adapts based on the build configuration:

#### Development Environment
```swift
LoggingConfig.configure(for: .development)
// - Console logging: ENABLED
// - Structured logging: ENABLED
// - OS Log: ENABLED
// - Minimum level: DEBUG
// - PII redaction: DISABLED (for easier debugging)
// - Correlation IDs: ENABLED
```

#### Staging Environment
```swift
LoggingConfig.configure(for: .staging)
// - Console logging: ENABLED
// - Structured logging: ENABLED
// - OS Log: ENABLED
// - Minimum level: INFO
// - PII redaction: ENABLED
// - Correlation IDs: ENABLED
```

#### Production Environment
```swift
LoggingConfig.configure(for: .production)
// - Console logging: DISABLED
// - Structured logging: ENABLED
// - OS Log: ENABLED
// - Minimum level: WARNING
// - PII redaction: ENABLED
// - Correlation IDs: ENABLED
```

### Runtime Configuration

```swift
// Change log level at runtime
LoggingConfig.setLogLevel(.debug)

// Toggle PII redaction
LoggingConfig.setPIIRedaction(enabled: true)

// Enable debug modes
LoggingConfig.enableAudioDebugMode()
LoggingConfig.enableBluetoothDebugMode()

// Disable all logging (for testing)
LoggingConfig.disableAllLogging()
```

---

## Best Practices

### DO ✅

1. **Use appropriate log levels**
   ```swift
   HelixLogger.debug("Variable x = \(x)")  // Development info
   HelixLogger.info("Service started")     // Production-worthy info
   HelixLogger.error("Operation failed", error: error)  // Errors
   ```

2. **Include relevant metadata**
   ```swift
   HelixLogger.info("User action", metadata: [
       "action": "button_tap",
       "screen": "home",
       "timestamp": "\(Date())"
   ])
   ```

3. **Use categories consistently**
   ```swift
   HelixLogger.bluetooth("Device discovered", level: .info)
   // NOT: HelixLogger.info("Device discovered", category: .general)
   ```

4. **Log errors with context**
   ```swift
   HelixLogger.error("Failed to save data", error: error, category: .general)
   ```

5. **Use correlation IDs for related operations**
   ```swift
   let correlationId = HelixLogger.generateCorrelationId()
   // All subsequent logs will include this correlation ID
   ```

### DON'T ❌

1. **Don't log sensitive information directly**
   ```swift
   // BAD
   HelixLogger.info("User email: user@example.com")

   // GOOD - PII redaction will handle this
   HelixLogger.info("User email: \(email)")  // Becomes "User email: [EMAIL_REDACTED]"
   ```

2. **Don't use print() statements**
   ```swift
   // BAD
   print("Bluetooth connected")

   // GOOD
   HelixLogger.bluetooth("Bluetooth connected", level: .info)
   ```

3. **Don't log in tight loops**
   ```swift
   // BAD
   for item in items {
       HelixLogger.debug("Processing item: \(item)")
   }

   // GOOD
   HelixLogger.debug("Processing batch", metadata: ["count": "\(items.count)"])
   ```

4. **Don't log without context**
   ```swift
   // BAD
   HelixLogger.error("Error occurred")

   // GOOD
   HelixLogger.error("Failed to connect to peripheral", error: error, category: .bluetooth)
   ```

---

## Examples

### Audio Service Example

```swift
class AudioService {
    func setupAudioSession() {
        let session = AVAudioSession.sharedInstance()

        do {
            try session.setCategory(.playAndRecord, mode: .default)
            HelixLogger.audio("Audio session configured", level: .info, metadata: [
                "category": session.category.rawValue,
                "mode": session.mode.rawValue
            ])
        } catch {
            HelixLogger.error("Audio session setup failed", error: error, category: .audio)
        }
    }
}
```

### Bluetooth Service Example

```swift
class BluetoothService {
    func connectToDevice(deviceName: String) {
        HelixLogger.bluetooth("Connecting to device", level: .info, metadata: [
            "deviceName": deviceName
        ])

        // Connection logic...

        if success {
            HelixLogger.bluetooth("Device connected successfully", level: .info)
        } else {
            HelixLogger.bluetooth("Connection failed", level: .error)
        }
    }
}
```

### Speech Recognition Example

```swift
class SpeechService {
    func startRecognition(language: String) {
        HelixLogger.speech("Starting speech recognition", level: .info, metadata: [
            "language": language
        ])

        // Recognition logic...
    }

    func handleRecognitionError(_ error: Error) {
        HelixLogger.error("Speech recognition failed", error: error, category: .speech)
    }
}
```

---

## PII Redaction

The logging system automatically redacts personally identifiable information (PII) to protect user privacy.

### Automatically Redacted Patterns

| Pattern | Example | Redacted As |
|---------|---------|-------------|
| Email addresses | `user@example.com` | `[EMAIL_REDACTED]` |
| Phone numbers | `+1-555-0123` | `[PHONE_REDACTED]` |
| UUIDs | `550e8400-e29b-41d4-a716-446655440000` | `550e8400-[REDACTED]` |
| IP addresses | `192.168.1.1` | `[IP_REDACTED]` |

### Example

```swift
let message = "User contact: john.doe@example.com, phone: +1-555-0123"
HelixLogger.info(message)

// Output (with PII redaction enabled):
// "User contact: [EMAIL_REDACTED], phone: [PHONE_REDACTED]"
```

### Controlling PII Redaction

```swift
// Disable in development for debugging
LoggingConfig.setPIIRedaction(enabled: false)

// Always enabled in production
// (set automatically by LoggingConfig.configure(for: .production))
```

---

## Correlation IDs

Correlation IDs help track related operations across different services and log entries.

### Generating Correlation IDs

```swift
// Generate a new correlation ID for an app session
let sessionId = HelixLogger.generateCorrelationId()

// All subsequent logs will include this correlation ID
HelixLogger.info("App started", metadata: ["sessionId": sessionId])
```

### Using Correlation IDs

```swift
// For a specific operation
let operationId = UUID().uuidString
HelixLogger.setCorrelationId(operationId)

HelixLogger.bluetooth("Starting device scan")
// ... scan logic ...
HelixLogger.bluetooth("Device scan completed")

// Clear correlation ID when operation completes
HelixLogger.setCorrelationId(nil)
```

### Example Output

```
[INFO] [Bluetooth] [CID:a1b2c3d4] Starting device scan (BluetoothManager.swift:45)
[INFO] [Bluetooth] [CID:a1b2c3d4] Device discovered (BluetoothManager.swift:67)
[INFO] [Bluetooth] [CID:a1b2c3d4] Device scan completed (BluetoothManager.swift:89)
```

---

## Performance Monitoring

The logging system includes built-in performance monitoring capabilities.

### Measuring Operation Duration

```swift
// Measure and automatically log execution time
let result = HelixLogger.measure("Database query", category: .general) {
    return performDatabaseQuery()
}

// Output:
// [INFO] [General] Performance: Database query {operation=Database query, duration_ms=45.23}
```

### Manual Performance Logging

```swift
let startTime = Date()
// ... perform operation ...
let duration = Date().timeIntervalSince(startTime)

HelixLogger.logPerformance(
    operation: "Image processing",
    duration: duration,
    category: .general
)
```

### Performance Thresholds

Configure performance thresholds to automatically log warnings:

```swift
// Defined in LoggingConfig.PerformanceThresholds
let threshold = LoggingConfig.PerformanceThresholds.audioProcessing  // 50ms

if duration > threshold {
    HelixLogger.warning("Performance threshold exceeded", category: .audio, metadata: [
        "operation": "audio processing",
        "duration_ms": "\(duration * 1000)",
        "threshold_ms": "\(threshold * 1000)"
    ])
}
```

---

## Log Output Formats

### Console Output (Human-Readable)

```
🔍 [DEBUG] [Audio] Audio Session Category: playAndRecord {mode=default, sampleRate=44100} (DebugHelper.swift:27)
ℹ️ [INFO] [Bluetooth] Device connected successfully {deviceName=Pair_001} (BluetoothManager.swift:131)
⚠️ [WARNING] [Speech] Recognition request is not available (SpeechStreamRecognizer.swift:170)
❌ [ERROR] [Audio] Failed to set basic audio category {error=Operation not permitted} (AppDelegate.swift:98)
```

### Structured JSON Output

```json
{
  "timestamp": "2025-11-16T10:30:45Z",
  "level": "INFO",
  "category": "Bluetooth",
  "message": "Device connected successfully",
  "correlationId": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",
  "context": {
    "file": "BluetoothManager.swift",
    "function": "centralManager(_:didConnect:)",
    "line": 131
  },
  "metadata": {
    "deviceName": "Pair_001",
    "uuid": "550e8400-[REDACTED]"
  }
}
```

### OS Log (System Console)

Integrated with Apple's unified logging system (iOS 14+):
- View in Console.app
- Searchable by subsystem: `com.helix.ios`
- Filterable by category: Audio, Bluetooth, Speech, etc.
- Supports log levels and metadata

---

## Migration Guide

### Migrating from `print()` statements

**Before:**
```swift
print("🎤 Audio session started")
print("❌ Error: \(error)")
```

**After:**
```swift
HelixLogger.audio("Audio session started", level: .info)
HelixLogger.error("Operation failed", error: error, category: .audio)
```

### Migrating from `NSLog`

**Before:**
```swift
NSLog("Bluetooth device connected: %@", deviceName)
```

**After:**
```swift
HelixLogger.bluetooth("Device connected", level: .info, metadata: [
    "deviceName": deviceName
])
```

---

## Troubleshooting

### Common Issues

**Issue**: Logs not appearing in console

**Solution**: Check minimum log level configuration
```swift
LoggingConfig.setLogLevel(.debug)
```

---

**Issue**: Too much debug output in production

**Solution**: Ensure production configuration is being used
```swift
LoggingConfig.configure(for: .production)  // Minimum level: WARNING
```

---

**Issue**: PII visible in logs

**Solution**: Enable PII redaction
```swift
LoggingConfig.setPIIRedaction(enabled: true)
```

---

## Summary

The Helix iOS logging system provides:

- ✅ Standardized logging across all services
- ✅ Multiple output formats (console, JSON, OS Log)
- ✅ Automatic PII redaction for privacy
- ✅ Correlation IDs for tracking related operations
- ✅ Category-based organization
- ✅ Environment-aware configuration
- ✅ Performance monitoring capabilities
- ✅ Rich contextual information

For questions or issues, please refer to the source code documentation in:
- `/ios/Runner/HelixLogger.swift`
- `/ios/Runner/LoggingConfig.swift`

---

**Last Updated**: 2025-11-16
**Version**: 1.0.0
