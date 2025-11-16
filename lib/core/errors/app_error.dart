/// Core error handling library for the application
/// Provides standardized error types, codes, and handling patterns

/// Error severity levels
enum ErrorSeverity {
  /// Debug-level errors (development only)
  debug,

  /// Informational errors (user should know but not critical)
  info,

  /// Warning errors (degraded functionality)
  warning,

  /// Error level (feature failure)
  error,

  /// Critical errors (app-level failure)
  critical,

  /// Fatal errors (requires restart)
  fatal,
}

/// Error categories for grouping and tracking
enum ErrorCategory {
  /// Network-related errors
  network,

  /// Authentication and authorization errors
  auth,

  /// API and service errors
  api,

  /// Bluetooth/BLE errors
  bluetooth,

  /// Audio processing errors
  audio,

  /// Transcription errors
  transcription,

  /// AI/LLM errors
  ai,

  /// Storage/persistence errors
  storage,

  /// Validation errors
  validation,

  /// Configuration errors
  configuration,

  /// Unknown/unexpected errors
  unknown,
}

/// Base application error class
/// All custom errors should extend this class
class AppError implements Exception {
  /// Unique error code for tracking and handling
  final String code;

  /// Human-readable error message
  final String message;

  /// Optional detailed description
  final String? details;

  /// Error severity level
  final ErrorSeverity severity;

  /// Error category
  final ErrorCategory category;

  /// Original error that caused this error (if any)
  final dynamic originalError;

  /// Stack trace from the error (if available)
  final StackTrace? stackTrace;

  /// Additional context data for debugging
  final Map<String, dynamic>? context;

  /// Timestamp when error occurred
  final DateTime timestamp;

  /// Whether this error is recoverable
  final bool isRecoverable;

  /// Suggested recovery action
  final String? recoveryAction;

  AppError({
    required this.code,
    required this.message,
    this.details,
    this.severity = ErrorSeverity.error,
    this.category = ErrorCategory.unknown,
    this.originalError,
    this.stackTrace,
    this.context,
    DateTime? timestamp,
    this.isRecoverable = false,
    this.recoveryAction,
  }) : timestamp = timestamp ?? DateTime.now();

  /// Create error from exception
  factory AppError.fromException(
    Exception exception, {
    String? code,
    ErrorSeverity? severity,
    ErrorCategory? category,
    StackTrace? stackTrace,
    Map<String, dynamic>? context,
  }) {
    return AppError(
      code: code ?? 'UNKNOWN_ERROR',
      message: exception.toString(),
      severity: severity ?? ErrorSeverity.error,
      category: category ?? ErrorCategory.unknown,
      originalError: exception,
      stackTrace: stackTrace,
      context: context,
    );
  }

  /// Convert error to JSON for logging/reporting
  Map<String, dynamic> toJson() {
    return {
      'code': code,
      'message': message,
      'details': details,
      'severity': severity.name,
      'category': category.name,
      'timestamp': timestamp.toIso8601String(),
      'isRecoverable': isRecoverable,
      'recoveryAction': recoveryAction,
      'context': context,
      'originalError': originalError?.toString(),
    };
  }

  /// Get user-friendly error message
  String getUserMessage() {
    return message;
  }

  /// Get developer-friendly error message
  String getDeveloperMessage() {
    final buffer = StringBuffer();
    buffer.writeln('[$code] $message');
    if (details != null) {
      buffer.writeln('Details: $details');
    }
    if (originalError != null) {
      buffer.writeln('Original: $originalError');
    }
    if (context != null && context!.isNotEmpty) {
      buffer.writeln('Context: $context');
    }
    return buffer.toString();
  }

  @override
  String toString() {
    return 'AppError($code): $message';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AppError && other.code == code && other.message == message;
  }

  @override
  int get hashCode => code.hashCode ^ message.hashCode;
}

/// Network-related errors
class NetworkError extends AppError {
  NetworkError({
    required String code,
    required String message,
    String? details,
    ErrorSeverity severity = ErrorSeverity.error,
    dynamic originalError,
    StackTrace? stackTrace,
    Map<String, dynamic>? context,
    bool isRecoverable = true,
    String? recoveryAction,
  }) : super(
          code: code,
          message: message,
          details: details,
          severity: severity,
          category: ErrorCategory.network,
          originalError: originalError,
          stackTrace: stackTrace,
          context: context,
          isRecoverable: isRecoverable,
          recoveryAction: recoveryAction ?? 'Check your internet connection and try again',
        );

  /// No internet connection
  factory NetworkError.noConnection() {
    return NetworkError(
      code: 'NETWORK_NO_CONNECTION',
      message: 'No internet connection',
      details: 'Please check your network settings',
      isRecoverable: true,
    );
  }

  /// Request timeout
  factory NetworkError.timeout({String? details}) {
    return NetworkError(
      code: 'NETWORK_TIMEOUT',
      message: 'Request timed out',
      details: details ?? 'The request took too long to complete',
      isRecoverable: true,
    );
  }

  /// Server error
  factory NetworkError.serverError({
    required int statusCode,
    String? details,
    dynamic originalError,
  }) {
    return NetworkError(
      code: 'NETWORK_SERVER_ERROR_$statusCode',
      message: 'Server error ($statusCode)',
      details: details,
      originalError: originalError,
      isRecoverable: statusCode >= 500 && statusCode < 600,
    );
  }
}

/// Authentication/Authorization errors
class AuthError extends AppError {
  AuthError({
    required String code,
    required String message,
    String? details,
    ErrorSeverity severity = ErrorSeverity.error,
    dynamic originalError,
    StackTrace? stackTrace,
    Map<String, dynamic>? context,
  }) : super(
          code: code,
          message: message,
          details: details,
          severity: severity,
          category: ErrorCategory.auth,
          originalError: originalError,
          stackTrace: stackTrace,
          context: context,
          isRecoverable: false,
        );

  /// Invalid API key
  factory AuthError.invalidApiKey({String? service}) {
    return AuthError(
      code: 'AUTH_INVALID_API_KEY',
      message: 'Invalid API key',
      details: service != null ? 'Invalid API key for $service' : null,
    );
  }

  /// Unauthorized access
  factory AuthError.unauthorized() {
    return AuthError(
      code: 'AUTH_UNAUTHORIZED',
      message: 'Unauthorized access',
      details: 'Authentication required',
    );
  }

  /// Permission denied
  factory AuthError.permissionDenied({String? permission}) {
    return AuthError(
      code: 'AUTH_PERMISSION_DENIED',
      message: 'Permission denied',
      details: permission != null ? 'Missing permission: $permission' : null,
    );
  }
}

/// API-related errors
class ApiError extends AppError {
  final int? statusCode;
  final String? responseBody;

  ApiError({
    required String code,
    required String message,
    String? details,
    ErrorSeverity severity = ErrorSeverity.error,
    this.statusCode,
    this.responseBody,
    dynamic originalError,
    StackTrace? stackTrace,
    Map<String, dynamic>? context,
    bool isRecoverable = false,
    String? recoveryAction,
  }) : super(
          code: code,
          message: message,
          details: details,
          severity: severity,
          category: ErrorCategory.api,
          originalError: originalError,
          stackTrace: stackTrace,
          context: {
            ...?context,
            if (statusCode != null) 'statusCode': statusCode,
            if (responseBody != null) 'responseBody': responseBody,
          },
          isRecoverable: isRecoverable,
          recoveryAction: recoveryAction,
        );

  /// Rate limit exceeded
  factory ApiError.rateLimitExceeded({String? retryAfter}) {
    return ApiError(
      code: 'API_RATE_LIMIT_EXCEEDED',
      message: 'API rate limit exceeded',
      details: retryAfter != null ? 'Retry after $retryAfter' : null,
      isRecoverable: true,
      recoveryAction: 'Please wait a moment and try again',
    );
  }

  /// Invalid request
  factory ApiError.invalidRequest({String? details}) {
    return ApiError(
      code: 'API_INVALID_REQUEST',
      message: 'Invalid API request',
      details: details,
    );
  }

  /// Service unavailable
  factory ApiError.serviceUnavailable({String? service}) {
    return ApiError(
      code: 'API_SERVICE_UNAVAILABLE',
      message: 'Service unavailable',
      details: service != null ? '$service is currently unavailable' : null,
      isRecoverable: true,
      recoveryAction: 'The service is temporarily unavailable. Please try again later',
    );
  }
}

/// Bluetooth/BLE errors
class BluetoothError extends AppError {
  BluetoothError({
    required String code,
    required String message,
    String? details,
    ErrorSeverity severity = ErrorSeverity.error,
    dynamic originalError,
    StackTrace? stackTrace,
    Map<String, dynamic>? context,
    bool isRecoverable = true,
    String? recoveryAction,
  }) : super(
          code: code,
          message: message,
          details: details,
          severity: severity,
          category: ErrorCategory.bluetooth,
          originalError: originalError,
          stackTrace: stackTrace,
          context: context,
          isRecoverable: isRecoverable,
          recoveryAction: recoveryAction,
        );

  /// Device not connected
  factory BluetoothError.notConnected() {
    return BluetoothError(
      code: 'BLE_NOT_CONNECTED',
      message: 'Device not connected',
      details: 'Please connect to your device first',
      recoveryAction: 'Connect to your device and try again',
    );
  }

  /// Connection timeout
  factory BluetoothError.connectionTimeout() {
    return BluetoothError(
      code: 'BLE_CONNECTION_TIMEOUT',
      message: 'Connection timeout',
      details: 'Failed to connect to device',
      recoveryAction: 'Make sure the device is nearby and try again',
    );
  }

  /// Device disconnected
  factory BluetoothError.disconnected() {
    return BluetoothError(
      code: 'BLE_DISCONNECTED',
      message: 'Device disconnected',
      details: 'The connection was lost',
      recoveryAction: 'Reconnect to your device',
    );
  }

  /// Bluetooth not available
  factory BluetoothError.notAvailable() {
    return BluetoothError(
      code: 'BLE_NOT_AVAILABLE',
      message: 'Bluetooth not available',
      details: 'Bluetooth is not enabled or not supported',
      recoveryAction: 'Enable Bluetooth on your device',
      isRecoverable: false,
    );
  }
}

/// Audio processing errors
class AudioError extends AppError {
  AudioError({
    required String code,
    required String message,
    String? details,
    ErrorSeverity severity = ErrorSeverity.error,
    dynamic originalError,
    StackTrace? stackTrace,
    Map<String, dynamic>? context,
    bool isRecoverable = true,
    String? recoveryAction,
  }) : super(
          code: code,
          message: message,
          details: details,
          severity: severity,
          category: ErrorCategory.audio,
          originalError: originalError,
          stackTrace: stackTrace,
          context: context,
          isRecoverable: isRecoverable,
          recoveryAction: recoveryAction,
        );

  /// Recording failed
  factory AudioError.recordingFailed({String? details, dynamic originalError}) {
    return AudioError(
      code: 'AUDIO_RECORDING_FAILED',
      message: 'Audio recording failed',
      details: details,
      originalError: originalError,
      recoveryAction: 'Check microphone permissions and try again',
    );
  }

  /// Playback failed
  factory AudioError.playbackFailed({String? details, dynamic originalError}) {
    return AudioError(
      code: 'AUDIO_PLAYBACK_FAILED',
      message: 'Audio playback failed',
      details: details,
      originalError: originalError,
    );
  }

  /// Permission denied
  factory AudioError.permissionDenied() {
    return AudioError(
      code: 'AUDIO_PERMISSION_DENIED',
      message: 'Microphone permission denied',
      details: 'Please grant microphone permission to use this feature',
      recoveryAction: 'Grant microphone permission in settings',
      isRecoverable: false,
    );
  }
}

/// Transcription errors
class TranscriptionServiceError extends AppError {
  TranscriptionServiceError({
    required String code,
    required String message,
    String? details,
    ErrorSeverity severity = ErrorSeverity.error,
    dynamic originalError,
    StackTrace? stackTrace,
    Map<String, dynamic>? context,
    bool isRecoverable = true,
    String? recoveryAction,
  }) : super(
          code: code,
          message: message,
          details: details,
          severity: severity,
          category: ErrorCategory.transcription,
          originalError: originalError,
          stackTrace: stackTrace,
          context: context,
          isRecoverable: isRecoverable,
          recoveryAction: recoveryAction,
        );

  /// Service not available
  factory TranscriptionServiceError.notAvailable({String? service}) {
    return TranscriptionServiceError(
      code: 'TRANSCRIPTION_NOT_AVAILABLE',
      message: 'Transcription service not available',
      details: service != null ? '$service is not available' : null,
      recoveryAction: 'Try using an alternative transcription service',
    );
  }

  /// Transcription failed
  factory TranscriptionServiceError.failed({String? details, dynamic originalError}) {
    return TranscriptionServiceError(
      code: 'TRANSCRIPTION_FAILED',
      message: 'Transcription failed',
      details: details,
      originalError: originalError,
    );
  }
}

/// AI/LLM errors
class AIError extends AppError {
  AIError({
    required String code,
    required String message,
    String? details,
    ErrorSeverity severity = ErrorSeverity.error,
    dynamic originalError,
    StackTrace? stackTrace,
    Map<String, dynamic>? context,
    bool isRecoverable = true,
    String? recoveryAction,
  }) : super(
          code: code,
          message: message,
          details: details,
          severity: severity,
          category: ErrorCategory.ai,
          originalError: originalError,
          stackTrace: stackTrace,
          context: context,
          isRecoverable: isRecoverable,
          recoveryAction: recoveryAction,
        );

  /// Service not ready
  factory AIError.notReady({String? service}) {
    return AIError(
      code: 'AI_NOT_READY',
      message: 'AI service not ready',
      details: service != null ? '$service is not initialized' : null,
      recoveryAction: 'Initialize the AI service before use',
      isRecoverable: false,
    );
  }

  /// Invalid response
  factory AIError.invalidResponse({String? details, dynamic originalError}) {
    return AIError(
      code: 'AI_INVALID_RESPONSE',
      message: 'Invalid AI response',
      details: details,
      originalError: originalError,
    );
  }

  /// Model error
  factory AIError.modelError({String? model, String? details, dynamic originalError}) {
    return AIError(
      code: 'AI_MODEL_ERROR',
      message: 'AI model error',
      details: details,
      originalError: originalError,
      context: {'model': model},
    );
  }
}

/// Storage/persistence errors
class StorageError extends AppError {
  StorageError({
    required String code,
    required String message,
    String? details,
    ErrorSeverity severity = ErrorSeverity.error,
    dynamic originalError,
    StackTrace? stackTrace,
    Map<String, dynamic>? context,
    bool isRecoverable = true,
    String? recoveryAction,
  }) : super(
          code: code,
          message: message,
          details: details,
          severity: severity,
          category: ErrorCategory.storage,
          originalError: originalError,
          stackTrace: stackTrace,
          context: context,
          isRecoverable: isRecoverable,
          recoveryAction: recoveryAction,
        );

  /// Read error
  factory StorageError.readFailed({String? path, dynamic originalError}) {
    return StorageError(
      code: 'STORAGE_READ_FAILED',
      message: 'Failed to read data',
      details: path != null ? 'Failed to read from $path' : null,
      originalError: originalError,
    );
  }

  /// Write error
  factory StorageError.writeFailed({String? path, dynamic originalError}) {
    return StorageError(
      code: 'STORAGE_WRITE_FAILED',
      message: 'Failed to write data',
      details: path != null ? 'Failed to write to $path' : null,
      originalError: originalError,
    );
  }

  /// Storage full
  factory StorageError.storageFull() {
    return StorageError(
      code: 'STORAGE_FULL',
      message: 'Storage is full',
      details: 'Not enough space available',
      recoveryAction: 'Free up some space and try again',
      isRecoverable: false,
    );
  }
}

/// Validation errors
class ValidationError extends AppError {
  final Map<String, List<String>>? fieldErrors;

  ValidationError({
    required String code,
    required String message,
    String? details,
    this.fieldErrors,
    ErrorSeverity severity = ErrorSeverity.warning,
    Map<String, dynamic>? context,
  }) : super(
          code: code,
          message: message,
          details: details,
          severity: severity,
          category: ErrorCategory.validation,
          context: {
            ...?context,
            if (fieldErrors != null) 'fieldErrors': fieldErrors,
          },
          isRecoverable: true,
        );

  /// Invalid input
  factory ValidationError.invalidInput({
    required String field,
    required String reason,
  }) {
    return ValidationError(
      code: 'VALIDATION_INVALID_INPUT',
      message: 'Invalid input',
      details: '$field: $reason',
      fieldErrors: {
        field: [reason],
      },
    );
  }

  /// Required field
  factory ValidationError.requiredField({required String field}) {
    return ValidationError(
      code: 'VALIDATION_REQUIRED_FIELD',
      message: 'Required field missing',
      details: '$field is required',
      fieldErrors: {
        field: ['This field is required'],
      },
    );
  }
}
