/// Centralized error logging with structured logging support

import 'package:flutter_helix/utils/app_logger.dart';
import 'app_error.dart';
import 'error_formatter.dart';

/// Error logging service with structured logging support
class ErrorLogger {
  static final ErrorLogger _instance = ErrorLogger._();
  static ErrorLogger get instance => _instance;

  ErrorLogger._();

  /// Error handlers for custom processing
  final List<ErrorHandler> _errorHandlers = [];

  /// Whether to log stack traces for all errors
  bool logStackTraces = true;

  /// Whether to include context in logs
  bool logContext = true;

  /// Register an error handler
  void registerHandler(ErrorHandler handler) {
    _errorHandlers.add(handler);
  }

  /// Remove an error handler
  void unregisterHandler(ErrorHandler handler) {
    _errorHandlers.remove(handler);
  }

  /// Log an error with appropriate severity
  void logError(
    dynamic error, {
    StackTrace? stackTrace,
    Map<String, dynamic>? context,
    String? source,
  }) {
    if (error is AppError) {
      _logAppError(error, source: source);
    } else {
      _logGenericError(error, stackTrace: stackTrace, context: context, source: source);
    }

    // Call registered handlers
    for (final handler in _errorHandlers) {
      try {
        handler.onError(error, stackTrace: stackTrace, context: context);
      } catch (e) {
        appLogger.e('Error handler failed', error: e);
      }
    }
  }

  /// Log an AppError with appropriate severity level
  void _logAppError(AppError error, {String? source}) {
    final message = _buildLogMessage(error, source: source);

    switch (error.severity) {
      case ErrorSeverity.debug:
        appLogger.d(message);
        break;
      case ErrorSeverity.info:
        appLogger.i(message);
        break;
      case ErrorSeverity.warning:
        appLogger.w(message);
        break;
      case ErrorSeverity.error:
        appLogger.e(
          message,
          error: error.originalError,
          stackTrace: logStackTraces ? error.stackTrace : null,
        );
        break;
      case ErrorSeverity.critical:
      case ErrorSeverity.fatal:
        appLogger.e(
          message,
          error: error.originalError,
          stackTrace: error.stackTrace,
        );
        break;
    }
  }

  /// Log a generic error
  void _logGenericError(
    dynamic error, {
    StackTrace? stackTrace,
    Map<String, dynamic>? context,
    String? source,
  }) {
    final message = _buildGenericLogMessage(error, context: context, source: source);
    appLogger.e(
      message,
      error: error,
      stackTrace: logStackTraces ? stackTrace : null,
    );
  }

  /// Build log message for AppError
  String _buildLogMessage(AppError error, {String? source}) {
    final buffer = StringBuffer();

    if (source != null) {
      buffer.write('[$source] ');
    }

    buffer.write('[${error.code}] ${error.message}');

    if (error.details != null) {
      buffer.write(' - ${error.details}');
    }

    if (logContext && error.context != null && error.context!.isNotEmpty) {
      buffer.write('\nContext: ${error.context}');
    }

    return buffer.toString();
  }

  /// Build log message for generic error
  String _buildGenericLogMessage(
    dynamic error, {
    Map<String, dynamic>? context,
    String? source,
  }) {
    final buffer = StringBuffer();

    if (source != null) {
      buffer.write('[$source] ');
    }

    buffer.write(error.toString());

    if (logContext && context != null && context.isNotEmpty) {
      buffer.write('\nContext: $context');
    }

    return buffer.toString();
  }

  /// Log a network error with detailed information
  void logNetworkError(
    NetworkError error, {
    String? url,
    String? method,
    Map<String, String>? headers,
    String? requestBody,
  }) {
    final context = <String, dynamic>{
      ...?error.context,
      if (url != null) 'url': url,
      if (method != null) 'method': method,
      if (headers != null) 'headers': headers,
      if (requestBody != null) 'requestBody': requestBody,
    };

    final errorWithContext = NetworkError(
      code: error.code,
      message: error.message,
      details: error.details,
      severity: error.severity,
      originalError: error.originalError,
      stackTrace: error.stackTrace,
      context: context,
      isRecoverable: error.isRecoverable,
      recoveryAction: error.recoveryAction,
    );

    _logAppError(errorWithContext, source: 'Network');
  }

  /// Log an API error with detailed information
  void logApiError(
    ApiError error, {
    String? endpoint,
    String? method,
    String? requestBody,
    String? responseBody,
  }) {
    final context = <String, dynamic>{
      ...?error.context,
      if (endpoint != null) 'endpoint': endpoint,
      if (method != null) 'method': method,
      if (requestBody != null) 'requestBody': requestBody,
      if (responseBody != null) 'responseBody': responseBody,
    };

    final errorWithContext = ApiError(
      code: error.code,
      message: error.message,
      details: error.details,
      severity: error.severity,
      statusCode: error.statusCode,
      responseBody: error.responseBody,
      originalError: error.originalError,
      stackTrace: error.stackTrace,
      context: context,
      isRecoverable: error.isRecoverable,
      recoveryAction: error.recoveryAction,
    );

    _logAppError(errorWithContext, source: 'API');
  }

  /// Log a Bluetooth error with device information
  void logBluetoothError(
    BluetoothError error, {
    String? deviceName,
    String? deviceId,
    String? operation,
  }) {
    final context = <String, dynamic>{
      ...?error.context,
      if (deviceName != null) 'deviceName': deviceName,
      if (deviceId != null) 'deviceId': deviceId,
      if (operation != null) 'operation': operation,
    };

    final errorWithContext = BluetoothError(
      code: error.code,
      message: error.message,
      details: error.details,
      severity: error.severity,
      originalError: error.originalError,
      stackTrace: error.stackTrace,
      context: context,
      isRecoverable: error.isRecoverable,
      recoveryAction: error.recoveryAction,
    );

    _logAppError(errorWithContext, source: 'Bluetooth');
  }

  /// Log validation errors
  void logValidationError(
    ValidationError error, {
    String? formName,
    Map<String, dynamic>? formData,
  }) {
    final context = <String, dynamic>{
      ...?error.context,
      if (formName != null) 'formName': formName,
      if (formData != null) 'formData': formData,
    };

    final errorWithContext = ValidationError(
      code: error.code,
      message: error.message,
      details: error.details,
      fieldErrors: error.fieldErrors,
      severity: error.severity,
      context: context,
    );

    _logAppError(errorWithContext, source: 'Validation');
  }

  /// Create and log a full error report
  void logErrorReport(
    dynamic error, {
    StackTrace? stackTrace,
    Map<String, dynamic>? context,
  }) {
    final report = ErrorFormatter.createErrorReport(
      error,
      stackTrace: stackTrace,
      context: context,
    );
    appLogger.e(report);
  }

  /// Log an error and return a user-friendly message
  String logAndGetUserMessage(
    dynamic error, {
    StackTrace? stackTrace,
    Map<String, dynamic>? context,
    String? source,
  }) {
    logError(error, stackTrace: stackTrace, context: context, source: source);
    return ErrorFormatter.formatForUser(error);
  }
}

/// Error handler interface for custom error processing
abstract class ErrorHandler {
  /// Called when an error is logged
  void onError(
    dynamic error, {
    StackTrace? stackTrace,
    Map<String, dynamic>? context,
  });
}

/// Analytics error handler - sends errors to analytics
class AnalyticsErrorHandler implements ErrorHandler {
  final Function(Map<String, dynamic>) trackError;

  AnalyticsErrorHandler(this.trackError);

  @override
  void onError(
    dynamic error, {
    StackTrace? stackTrace,
    Map<String, dynamic>? context,
  }) {
    final errorData = ErrorFormatter.formatForJson(
      error,
      stackTrace: stackTrace,
      additionalContext: context,
    );
    trackError(errorData);
  }
}

/// Crash reporting error handler - sends critical errors to crash reporting service
class CrashReportingErrorHandler implements ErrorHandler {
  final Function(dynamic, StackTrace?) reportCrash;

  CrashReportingErrorHandler(this.reportCrash);

  @override
  void onError(
    dynamic error, {
    StackTrace? stackTrace,
    Map<String, dynamic>? context,
  }) {
    // Only report critical and fatal errors
    if (error is AppError) {
      if (error.severity == ErrorSeverity.critical ||
          error.severity == ErrorSeverity.fatal) {
        reportCrash(error, stackTrace ?? error.stackTrace);
      }
    } else {
      // Report all non-AppError exceptions as they're unexpected
      reportCrash(error, stackTrace);
    }
  }
}

/// Convenience method for quick error logging
void logError(
  dynamic error, {
  StackTrace? stackTrace,
  Map<String, dynamic>? context,
  String? source,
}) {
  ErrorLogger.instance.logError(
    error,
    stackTrace: stackTrace,
    context: context,
    source: source,
  );
}
