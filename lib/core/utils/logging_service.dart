// ABOUTME: Simple logging service for application-wide logging
// ABOUTME: Provides structured logging with different severity levels

// ignore_for_file: avoid_print

enum LogLevel {
  debug,
  info,
  warning,
  error,
}

class LoggingService {
  static final LoggingService _instance = LoggingService._();
  static LoggingService get instance => _instance;

  LoggingService._();

  void log(String tag, String message, LogLevel level, [Object? data]) {
    _log(level.name.toUpperCase(), tag, message, data);
  }

  void debug(String tag, String message, [Object? data]) {
    _log('DEBUG', tag, message, data);
  }

  void info(String tag, String message, [Object? data]) {
    _log('INFO', tag, message, data);
  }

  void warning(String tag, String message, [Object? data]) {
    _log('WARNING', tag, message, data);
  }

  void error(String tag, String message, [Object? error, StackTrace? stackTrace]) {
    _log('ERROR', tag, message, error);
    if (stackTrace != null) {
      print('[ERROR][$tag] StackTrace: $stackTrace');
    }
  }

  void _log(String level, String tag, String message, [Object? data]) {
    final String timestamp = DateTime.now().toIso8601String();
    print('[$timestamp][$level][$tag] $message${data != null ? ' | Data: $data' : ''}');
  }
}
