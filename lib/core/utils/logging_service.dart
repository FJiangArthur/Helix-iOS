// ABOUTME: Enhanced logging service with debugging features and file output
// ABOUTME: Provides consistent logging across all app components with filtering and debug tools

import 'dart:developer' as developer;
import 'dart:io';
import 'dart:convert';

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
  
  // Debug features
  bool _fileLoggingEnabled = false;
  String? _logFilePath;
  bool _performanceLoggingEnabled = false;
  final Map<String, DateTime> _performanceMarkers = {};
  
  // Filtering and search
  Set<String> _tagFilters = {};
  String? _messageFilter;

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
  
  // ==========================================================================
  // Debug and Advanced Features  
  // ==========================================================================
  
  /// Enable file logging to a specified path
  Future<void> enableFileLogging(String filePath) async {
    try {
      _logFilePath = filePath;
      final file = File(filePath);
      await file.create(recursive: true);
      _fileLoggingEnabled = true;
      log('LoggingService', 'File logging enabled: $filePath', LogLevel.info);
    } catch (e) {
      log('LoggingService', 'Failed to enable file logging: $e', LogLevel.error);
    }
  }
  
  /// Disable file logging
  void disableFileLogging() {
    _fileLoggingEnabled = false;
    _logFilePath = null;
    log('LoggingService', 'File logging disabled', LogLevel.info);
  }
  
  /// Enable performance logging for timing operations
  void enablePerformanceLogging() {
    _performanceLoggingEnabled = true;
    log('LoggingService', 'Performance logging enabled', LogLevel.info);
  }
  
  /// Disable performance logging
  void disablePerformanceLogging() {
    _performanceLoggingEnabled = false;
    _performanceMarkers.clear();
    log('LoggingService', 'Performance logging disabled', LogLevel.info);
  }
  
  /// Start a performance timing marker
  void startPerformanceTimer(String markerId) {
    if (!_performanceLoggingEnabled) return;
    _performanceMarkers[markerId] = DateTime.now();
    log('Performance', 'Started timer: $markerId', LogLevel.debug);
  }
  
  /// End a performance timing marker and log the duration
  void endPerformanceTimer(String markerId, [String? operation]) {
    if (!_performanceLoggingEnabled) return;
    
    final startTime = _performanceMarkers.remove(markerId);
    if (startTime == null) {
      log('Performance', 'Timer not found: $markerId', LogLevel.warning);
      return;
    }
    
    final duration = DateTime.now().difference(startTime);
    final op = operation ?? markerId;
    log('Performance', '$op completed in ${duration.inMilliseconds}ms', LogLevel.info);
  }
  
  /// Add tag filters - only logs from these tags will be shown
  void addTagFilter(String tag) {
    _tagFilters.add(tag);
    log('LoggingService', 'Added tag filter: $tag', LogLevel.debug);
  }
  
  /// Remove a tag filter
  void removeTagFilter(String tag) {
    _tagFilters.remove(tag);
    log('LoggingService', 'Removed tag filter: $tag', LogLevel.debug);
  }
  
  /// Clear all tag filters
  void clearTagFilters() {
    _tagFilters.clear();
    log('LoggingService', 'Cleared all tag filters', LogLevel.debug);
  }
  
  /// Set message filter - only logs containing this text will be shown
  void setMessageFilter(String? filter) {
    _messageFilter = filter;
    log('LoggingService', filter != null ? 'Set message filter: $filter' : 'Cleared message filter', LogLevel.debug);
  }
  
  /// Get filtered logs based on current filters
  List<LogEntry> getFilteredLogs({
    LogLevel? minLevel,
    String? tag,
    DateTime? since,
    int? limit,
  }) {
    var filtered = _logs.where((entry) {
      // Level filter
      if (minLevel != null && entry.level.index < minLevel.index) return false;
      
      // Tag filter
      if (tag != null && entry.tag != tag) return false;
      if (_tagFilters.isNotEmpty && !_tagFilters.contains(entry.tag)) return false;
      
      // Message filter
      if (_messageFilter != null && !entry.message.toLowerCase().contains(_messageFilter!.toLowerCase())) return false;
      
      // Time filter
      if (since != null && entry.timestamp.isBefore(since)) return false;
      
      return true;
    }).toList();
    
    if (limit != null && filtered.length > limit) {
      filtered = filtered.take(limit).toList();
    }
    
    return filtered;
  }
  
  /// Export logs to JSON format
  String exportLogsAsJson({
    LogLevel? minLevel,
    String? tag,
    DateTime? since,
  }) {
    final filtered = getFilteredLogs(minLevel: minLevel, tag: tag, since: since);
    final jsonData = filtered.map((entry) => {
      'timestamp': entry.timestamp.toIso8601String(),
      'level': entry.level.name,
      'tag': entry.tag,
      'message': entry.message,
    }).toList();
    
    return jsonEncode(jsonData);
  }
  
  /// Export logs to plain text format
  String exportLogsAsText({
    LogLevel? minLevel,
    String? tag,
    DateTime? since,
  }) {
    final filtered = getFilteredLogs(minLevel: minLevel, tag: tag, since: since);
    return filtered.map((entry) => entry.toString()).join('\n');
  }
  
  /// Get logging statistics
  Map<String, dynamic> getLoggingStats() {
    final now = DateTime.now();
    final oneHourAgo = now.subtract(const Duration(hours: 1));
    final oneDayAgo = now.subtract(const Duration(days: 1));
    
    final recentLogs = _logs.where((log) => log.timestamp.isAfter(oneHourAgo)).toList();
    final dailyLogs = _logs.where((log) => log.timestamp.isAfter(oneDayAgo)).toList();
    
    final levelCounts = <String, int>{};
    final tagCounts = <String, int>{};
    
    for (final log in _logs) {
      levelCounts[log.level.name] = (levelCounts[log.level.name] ?? 0) + 1;
      tagCounts[log.tag] = (tagCounts[log.tag] ?? 0) + 1;
    }
    
    return {
      'totalLogs': _logs.length,
      'recentLogs': recentLogs.length,
      'dailyLogs': dailyLogs.length,
      'levelCounts': levelCounts,
      'topTags': tagCounts.entries.toList()..sort((a, b) => b.value.compareTo(a.value)),
      'fileLoggingEnabled': _fileLoggingEnabled,
      'performanceLoggingEnabled': _performanceLoggingEnabled,
      'activeFilters': {
        'tagFilters': _tagFilters.toList(),
        'messageFilter': _messageFilter,
      },
    };
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
    
    // Output to file if enabled
    if (_fileLoggingEnabled && _logFilePath != null) {
      _writeToFile(entry);
    }
  }
  
  void _writeToFile(LogEntry entry) async {
    try {
      final file = File(_logFilePath!);
      final logLine = '${entry.toString()}\n';
      await file.writeAsString(logLine, mode: FileMode.append);
    } catch (e) {
      // Avoid infinite recursion by not logging this error
      developer.log('Failed to write to log file: $e', name: 'LoggingService');
    }
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

// ==========================================================================
// Debug Helper Functions
// ==========================================================================

/// Debug helper to log function entry with parameters
void logFunctionEntry(String className, String functionName, [Map<String, dynamic>? params]) {
  final paramStr = params?.entries.map((e) => '${e.key}=${e.value}').join(', ') ?? '';
  logger.debug(className, 'ENTER $functionName($paramStr)');
}

/// Debug helper to log function exit with return value
void logFunctionExit(String className, String functionName, [dynamic returnValue]) {
  final retStr = returnValue != null ? ' -> $returnValue' : '';
  logger.debug(className, 'EXIT $functionName$retStr');
}

/// Debug helper to log state changes
void logStateChange(String className, String property, dynamic oldValue, dynamic newValue) {
  logger.debug(className, 'STATE CHANGE $property: $oldValue -> $newValue');
}

/// Debug helper to log API calls
void logApiCall(String endpoint, String method, [Map<String, dynamic>? data]) {
  final dataStr = data != null ? ' with data: $data' : '';
  logger.info('API', '$method $endpoint$dataStr');
}

/// Debug helper to log API responses
void logApiResponse(String endpoint, int statusCode, [dynamic response]) {
  final respStr = response != null ? ' response: $response' : '';
  logger.info('API', '$endpoint returned $statusCode$respStr');
}

/// Debug helper to log user interactions  
void logUserAction(String action, [Map<String, dynamic>? context]) {
  final contextStr = context?.entries.map((e) => '${e.key}=${e.value}').join(', ') ?? '';
  logger.info('USER', 'Action: $action${contextStr.isNotEmpty ? ' ($contextStr)' : ''}');
}

/// Debug helper to log memory usage (simplified)
void logMemoryUsage(String tag) {
  // Note: Dart doesn't have direct memory introspection, but we can log process info
  logger.debug(tag, 'Memory check requested (detailed memory info not available in Dart)');
}

/// Debug helper for recording session management
void logRecordingEvent(String event, [Map<String, dynamic>? details]) {
  final detailStr = details?.entries.map((e) => '${e.key}=${e.value}').join(', ') ?? '';
  logger.info('RECORDING', '$event${detailStr.isNotEmpty ? ' ($detailStr)' : ''}');
}

/// Debug helper for audio processing
void logAudioEvent(String event, {double? level, Duration? duration, String? details}) {
  var message = event;
  if (level != null) message += ' level=${level.toStringAsFixed(3)}';
  if (duration != null) message += ' duration=${duration.inMilliseconds}ms';
  if (details != null) message += ' $details';
  logger.debug('AUDIO', message);
}

/// Debug helper for conversation processing
void logConversationEvent(String event, String conversationId, [String? details]) {
  var message = '$event conversationId=$conversationId';
  if (details != null) message += ' $details';
  logger.info('CONVERSATION', message);
}