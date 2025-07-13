// ABOUTME: Centralized logging service with multiple levels and output options
// ABOUTME: Provides consistent logging across all app components with filtering

import 'dart:developer' as developer;

enum LogLevel {
  debug,
  info,
  warning,
  error,
  critical,
}

class LoggingService {
  static LoggingService? _instance;
  static LoggingService get instance => _instance ??= LoggingService._();
  
  LoggingService._();

  LogLevel _currentLevel = LogLevel.debug;
  final List<LogEntry> _logs = [];
  final int _maxLogEntries = 1000;

  /// Set the minimum log level that will be output
  void setLogLevel(LogLevel level) {
    _currentLevel = level;
    log('LoggingService', 'Log level set to ${level.name}', LogLevel.info);
  }

  /// Log a message with specified level
  void log(String tag, String message, LogLevel level) {
    if (level.index < _currentLevel.index) return;

    final entry = LogEntry(
      timestamp: DateTime.now(),
      tag: tag,
      message: message,
      level: level,
    );

    _addLogEntry(entry);
    _outputLog(entry);
  }

  /// Convenience methods for different log levels
  void debug(String tag, String message) => log(tag, message, LogLevel.debug);
  void info(String tag, String message) => log(tag, message, LogLevel.info);
  void warning(String tag, String message) => log(tag, message, LogLevel.warning);
  void error(String tag, String message, [Object? error, StackTrace? stackTrace]) {
    String fullMessage = message;
    if (error != null) {
      fullMessage += '\nError: $error';
    }
    if (stackTrace != null) {
      fullMessage += '\nStack trace:\n$stackTrace';
    }
    log(tag, fullMessage, LogLevel.error);
  }
  void critical(String tag, String message, [Object? error, StackTrace? stackTrace]) {
    String fullMessage = message;
    if (error != null) {
      fullMessage += '\nError: $error';
    }
    if (stackTrace != null) {
      fullMessage += '\nStack trace:\n$stackTrace';
    }
    log(tag, fullMessage, LogLevel.critical);
  }

  /// Get recent log entries
  List<LogEntry> getRecentLogs([int? limit]) {
    if (limit == null) return List.unmodifiable(_logs);
    return List.unmodifiable(_logs.take(limit));
  }

  /// Clear all stored logs
  void clearLogs() {
    _logs.clear();
    log('LoggingService', 'Log history cleared', LogLevel.info);
  }

  void _addLogEntry(LogEntry entry) {
    _logs.insert(0, entry); // Add to beginning for most recent first
    
    // Maintain max log entries
    if (_logs.length > _maxLogEntries) {
      _logs.removeRange(_maxLogEntries, _logs.length);
    }
  }

  void _outputLog(LogEntry entry) {
    final formattedMessage = '[${entry.level.name.toUpperCase()}] ${entry.tag}: ${entry.message}';
    
    // Output to developer console
    developer.log(
      formattedMessage,
      time: entry.timestamp,
      level: _getDeveloperLogLevel(entry.level),
      name: entry.tag,
    );
  }

  int _getDeveloperLogLevel(LogLevel level) {
    switch (level) {
      case LogLevel.debug:
        return 500;
      case LogLevel.info:
        return 800;
      case LogLevel.warning:
        return 900;
      case LogLevel.error:
        return 1000;
      case LogLevel.critical:
        return 1200;
    }
  }
}

class LogEntry {
  final DateTime timestamp;
  final String tag;
  final String message;
  final LogLevel level;

  LogEntry({
    required this.timestamp,
    required this.tag,
    required this.message,
    required this.level,
  });

  @override
  String toString() {
    return '${timestamp.toIso8601String()} [${level.name.toUpperCase()}] $tag: $message';
  }
}

/// Global logger instance for convenience
final logger = LoggingService.instance;