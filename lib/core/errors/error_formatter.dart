/// Error formatting utilities for consistent error display and logging

import 'app_error.dart';

/// Error formatter for converting errors to user-friendly messages
class ErrorFormatter {
  /// Format error for user display
  static String formatForUser(dynamic error) {
    if (error is AppError) {
      return error.getUserMessage();
    } else if (error is Exception) {
      return _formatException(error);
    } else if (error is Error) {
      return 'An unexpected error occurred';
    } else {
      return error.toString();
    }
  }

  /// Format error for developer/logging
  static String formatForDeveloper(dynamic error, {StackTrace? stackTrace}) {
    final buffer = StringBuffer();

    if (error is AppError) {
      buffer.writeln('=== AppError ===');
      buffer.writeln('Code: ${error.code}');
      buffer.writeln('Message: ${error.message}');
      buffer.writeln('Category: ${error.category.name}');
      buffer.writeln('Severity: ${error.severity.name}');
      buffer.writeln('Recoverable: ${error.isRecoverable}');
      buffer.writeln('Timestamp: ${error.timestamp.toIso8601String()}');

      if (error.details != null) {
        buffer.writeln('Details: ${error.details}');
      }

      if (error.recoveryAction != null) {
        buffer.writeln('Recovery: ${error.recoveryAction}');
      }

      if (error.context != null && error.context!.isNotEmpty) {
        buffer.writeln('Context: ${error.context}');
      }

      if (error.originalError != null) {
        buffer.writeln('Original Error: ${error.originalError}');
      }

      if (error.stackTrace != null) {
        buffer.writeln('Stack Trace:\n${error.stackTrace}');
      }
    } else if (error is Exception) {
      buffer.writeln('=== Exception ===');
      buffer.writeln(error.toString());
    } else if (error is Error) {
      buffer.writeln('=== Error ===');
      buffer.writeln(error.toString());
      if (error.stackTrace != null) {
        buffer.writeln('Stack Trace:\n${error.stackTrace}');
      }
    } else {
      buffer.writeln('=== Unknown Error ===');
      buffer.writeln(error.toString());
    }

    if (stackTrace != null && error is! AppError) {
      buffer.writeln('Stack Trace:\n$stackTrace');
    }

    return buffer.toString();
  }

  /// Format error for JSON logging/reporting
  static Map<String, dynamic> formatForJson(
    dynamic error, {
    StackTrace? stackTrace,
    Map<String, dynamic>? additionalContext,
  }) {
    final Map<String, dynamic> json = {
      'timestamp': DateTime.now().toIso8601String(),
      'type': error.runtimeType.toString(),
    };

    if (error is AppError) {
      json.addAll(error.toJson());
    } else if (error is Exception) {
      json['message'] = error.toString();
      json['category'] = 'exception';
    } else if (error is Error) {
      json['message'] = error.toString();
      json['category'] = 'error';
      if (error.stackTrace != null) {
        json['stackTrace'] = error.stackTrace.toString();
      }
    } else {
      json['message'] = error.toString();
      json['category'] = 'unknown';
    }

    if (stackTrace != null && error is! AppError) {
      json['stackTrace'] = stackTrace.toString();
    }

    if (additionalContext != null) {
      json['additionalContext'] = additionalContext;
    }

    return json;
  }

  /// Format validation errors for user display
  static String formatValidationErrors(ValidationError error) {
    if (error.fieldErrors == null || error.fieldErrors!.isEmpty) {
      return error.message;
    }

    final buffer = StringBuffer();
    buffer.writeln(error.message);

    error.fieldErrors!.forEach((field, errors) {
      buffer.writeln('  • $field: ${errors.join(", ")}');
    });

    return buffer.toString().trim();
  }

  /// Get a user-friendly message based on error category
  static String getCategoryMessage(ErrorCategory category) {
    switch (category) {
      case ErrorCategory.network:
        return 'A network error occurred. Please check your connection.';
      case ErrorCategory.auth:
        return 'Authentication failed. Please check your credentials.';
      case ErrorCategory.api:
        return 'The service encountered an error. Please try again.';
      case ErrorCategory.bluetooth:
        return 'Bluetooth connection error. Please check your device.';
      case ErrorCategory.audio:
        return 'Audio error occurred. Please check your permissions.';
      case ErrorCategory.transcription:
        return 'Transcription failed. Please try again.';
      case ErrorCategory.ai:
        return 'AI service error. Please try again.';
      case ErrorCategory.storage:
        return 'Storage error occurred. Please check available space.';
      case ErrorCategory.validation:
        return 'Please check your input and try again.';
      case ErrorCategory.configuration:
        return 'Configuration error. Please check your settings.';
      case ErrorCategory.unknown:
        return 'An unexpected error occurred. Please try again.';
    }
  }

  /// Get emoji/icon for error category
  static String getCategoryIcon(ErrorCategory category) {
    switch (category) {
      case ErrorCategory.network:
        return '🌐';
      case ErrorCategory.auth:
        return '🔒';
      case ErrorCategory.api:
        return '🔌';
      case ErrorCategory.bluetooth:
        return '📡';
      case ErrorCategory.audio:
        return '🎤';
      case ErrorCategory.transcription:
        return '📝';
      case ErrorCategory.ai:
        return '🤖';
      case ErrorCategory.storage:
        return '💾';
      case ErrorCategory.validation:
        return '⚠️';
      case ErrorCategory.configuration:
        return '⚙️';
      case ErrorCategory.unknown:
        return '❓';
    }
  }

  /// Get color/severity indicator for error
  static String getSeverityIndicator(ErrorSeverity severity) {
    switch (severity) {
      case ErrorSeverity.debug:
        return '🔍';
      case ErrorSeverity.info:
        return 'ℹ️';
      case ErrorSeverity.warning:
        return '⚠️';
      case ErrorSeverity.error:
        return '❌';
      case ErrorSeverity.critical:
        return '🔥';
      case ErrorSeverity.fatal:
        return '💀';
    }
  }

  /// Create a formatted error report
  static String createErrorReport(
    dynamic error, {
    StackTrace? stackTrace,
    Map<String, dynamic>? context,
  }) {
    final buffer = StringBuffer();
    final timestamp = DateTime.now().toIso8601String();

    buffer.writeln('═══════════════════════════════════════');
    buffer.writeln('ERROR REPORT - $timestamp');
    buffer.writeln('═══════════════════════════════════════');
    buffer.writeln();

    if (error is AppError) {
      buffer.writeln('${getSeverityIndicator(error.severity)} ${getCategoryIcon(error.category)} ${error.code}');
      buffer.writeln();
      buffer.writeln('Message: ${error.message}');
      if (error.details != null) {
        buffer.writeln('Details: ${error.details}');
      }
      buffer.writeln();
      buffer.writeln('Category: ${error.category.name}');
      buffer.writeln('Severity: ${error.severity.name}');
      buffer.writeln('Recoverable: ${error.isRecoverable}');
      if (error.recoveryAction != null) {
        buffer.writeln('Recovery: ${error.recoveryAction}');
      }
      buffer.writeln();

      if (error.context != null && error.context!.isNotEmpty) {
        buffer.writeln('Context:');
        error.context!.forEach((key, value) {
          buffer.writeln('  $key: $value');
        });
        buffer.writeln();
      }

      if (error.originalError != null) {
        buffer.writeln('Original Error:');
        buffer.writeln('  ${error.originalError}');
        buffer.writeln();
      }
    } else {
      buffer.writeln('Type: ${error.runtimeType}');
      buffer.writeln('Message: $error');
      buffer.writeln();
    }

    if (context != null && context.isNotEmpty) {
      buffer.writeln('Additional Context:');
      context.forEach((key, value) {
        buffer.writeln('  $key: $value');
      });
      buffer.writeln();
    }

    if (stackTrace != null || (error is AppError && error.stackTrace != null)) {
      buffer.writeln('Stack Trace:');
      buffer.writeln(stackTrace ?? (error as AppError).stackTrace);
      buffer.writeln();
    }

    buffer.writeln('═══════════════════════════════════════');

    return buffer.toString();
  }

  static String _formatException(Exception exception) {
    final String message = exception.toString();

    // Remove common prefixes
    if (message.startsWith('Exception: ')) {
      return message.substring('Exception: '.length);
    }

    // Handle common exception types
    if (exception is FormatException) {
      return 'Invalid format: ${exception.message}';
    }

    if (exception is ArgumentError) {
      final argError = exception as ArgumentError;
      return 'Invalid argument: ${argError.message ?? argError.toString()}';
    }

    return message;
  }
}
