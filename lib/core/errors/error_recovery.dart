/// Error recovery strategies and utilities

import 'dart:async';
import 'app_error.dart';
import 'error_logger.dart';

/// Result type for operations that can fail
/// Inspired by Rust's Result and Swift's Result
class Result<T, E extends AppError> {
  final T? _value;
  final E? _error;

  const Result._(this._value, this._error);

  /// Create a successful result
  const Result.success(T value) : this._(value, null);

  /// Create a failed result
  const Result.failure(E error) : this._(null, error);

  /// Check if result is successful
  bool get isSuccess => _value != null;

  /// Check if result is a failure
  bool get isFailure => _error != null;

  /// Get the value (throws if error)
  T get value {
    if (_error != null) {
      throw _error!;
    }
    return _value!;
  }

  /// Get the error (returns null if success)
  E? get error => _error;

  /// Get the value or return a default
  T getOrDefault(T defaultValue) {
    return _value ?? defaultValue;
  }

  /// Get the value or compute a default
  T getOrElse(T Function() defaultFn) {
    return _value ?? defaultFn();
  }

  /// Get the value or throw the error
  T getOrThrow() {
    if (_error != null) {
      throw _error!;
    }
    return _value!;
  }

  /// Transform the value if success
  Result<R, E> map<R>(R Function(T) fn) {
    if (_value != null) {
      try {
        return Result.success(fn(_value!));
      } catch (e, stackTrace) {
        if (e is E) {
          return Result.failure(e);
        }
        rethrow;
      }
    }
    return Result.failure(_error!);
  }

  /// Transform the error if failure
  Result<T, F> mapError<F extends AppError>(F Function(E) fn) {
    if (_error != null) {
      return Result.failure(fn(_error!));
    }
    return Result.success(_value!);
  }

  /// Flat map for chaining results
  Result<R, E> flatMap<R>(Result<R, E> Function(T) fn) {
    if (_value != null) {
      return fn(_value!);
    }
    return Result.failure(_error!);
  }

  /// Execute a function if success
  void onSuccess(void Function(T) fn) {
    if (_value != null) {
      fn(_value!);
    }
  }

  /// Execute a function if failure
  void onFailure(void Function(E) fn) {
    if (_error != null) {
      fn(_error!);
    }
  }

  /// Execute appropriate function based on result
  R fold<R>(
    R Function(T) onSuccess,
    R Function(E) onFailure,
  ) {
    if (_value != null) {
      return onSuccess(_value!);
    }
    return onFailure(_error!);
  }

  @override
  String toString() {
    if (_value != null) {
      return 'Result.success($_value)';
    }
    return 'Result.failure($_error)';
  }
}

/// Extension for Future<Result>
extension FutureResultExtension<T, E extends AppError> on Future<Result<T, E>> {
  /// Transform the value if success
  Future<Result<R, E>> map<R>(R Function(T) fn) async {
    final result = await this;
    return result.map(fn);
  }

  /// Flat map for chaining async results
  Future<Result<R, E>> flatMap<R>(Future<Result<R, E>> Function(T) fn) async {
    final result = await this;
    if (result.isSuccess) {
      return fn(result.value);
    }
    return Result.failure(result.error!);
  }

  /// Execute a function if success
  Future<void> onSuccess(void Function(T) fn) async {
    final result = await this;
    result.onSuccess(fn);
  }

  /// Execute a function if failure
  Future<void> onFailure(void Function(E) fn) async {
    final result = await this;
    result.onFailure(fn);
  }
}

/// Error recovery strategies
class ErrorRecovery {
  /// Retry an operation with exponential backoff
  static Future<Result<T, AppError>> retryWithBackoff<T>({
    required Future<T> Function() operation,
    int maxAttempts = 3,
    Duration initialDelay = const Duration(milliseconds: 500),
    double backoffMultiplier = 2.0,
    bool Function(dynamic error)? shouldRetry,
  }) async {
    int attempt = 0;
    Duration delay = initialDelay;

    while (attempt < maxAttempts) {
      try {
        final result = await operation();
        return Result.success(result);
      } catch (e, stackTrace) {
        attempt++;

        // Check if we should retry this error
        if (shouldRetry != null && !shouldRetry(e)) {
          logError(e, stackTrace: stackTrace, context: {'attempt': attempt});
          return Result.failure(_toAppError(e, stackTrace));
        }

        // Last attempt - fail
        if (attempt >= maxAttempts) {
          logError(
            e,
            stackTrace: stackTrace,
            context: {'attempt': attempt, 'maxAttempts': maxAttempts},
          );
          return Result.failure(_toAppError(e, stackTrace));
        }

        // Log retry attempt
        logError(
          e,
          stackTrace: stackTrace,
          context: {
            'attempt': attempt,
            'maxAttempts': maxAttempts,
            'nextRetryIn': delay.inMilliseconds,
          },
          source: 'Retry',
        );

        // Wait before retry
        await Future.delayed(delay);
        delay *= backoffMultiplier;
      }
    }

    // Should never reach here, but just in case
    return Result.failure(
      AppError(
        code: 'RETRY_EXHAUSTED',
        message: 'All retry attempts exhausted',
        severity: ErrorSeverity.error,
      ),
    );
  }

  /// Execute operation with timeout
  static Future<Result<T, AppError>> withTimeout<T>({
    required Future<T> Function() operation,
    required Duration timeout,
    String? timeoutMessage,
  }) async {
    try {
      final result = await operation().timeout(
        timeout,
        onTimeout: () {
          throw NetworkError.timeout(
            details: timeoutMessage ?? 'Operation timed out after ${timeout.inSeconds}s',
          );
        },
      );
      return Result.success(result);
    } catch (e, stackTrace) {
      logError(e, stackTrace: stackTrace, context: {'timeout': timeout.inSeconds});
      return Result.failure(_toAppError(e, stackTrace));
    }
  }

  /// Execute operation with fallback
  static Future<Result<T, AppError>> withFallback<T>({
    required Future<T> Function() primary,
    required Future<T> Function() fallback,
    String? fallbackReason,
  }) async {
    try {
      final result = await primary();
      return Result.success(result);
    } catch (primaryError, primaryStackTrace) {
      logError(
        primaryError,
        stackTrace: primaryStackTrace,
        source: 'Primary',
        context: {'fallbackReason': fallbackReason ?? 'Primary operation failed'},
      );

      try {
        final result = await fallback();
        return Result.success(result);
      } catch (fallbackError, fallbackStackTrace) {
        logError(
          fallbackError,
          stackTrace: fallbackStackTrace,
          source: 'Fallback',
          context: {'primaryError': primaryError.toString()},
        );
        return Result.failure(_toAppError(fallbackError, fallbackStackTrace));
      }
    }
  }

  /// Execute multiple operations and return first success
  static Future<Result<T, AppError>> firstSuccess<T>({
    required List<Future<T> Function()> operations,
    String? operationName,
  }) async {
    final errors = <dynamic>[];

    for (int i = 0; i < operations.length; i++) {
      try {
        final result = await operations[i]();
        return Result.success(result);
      } catch (e, stackTrace) {
        errors.add({'error': e, 'stackTrace': stackTrace, 'index': i});
        logError(
          e,
          stackTrace: stackTrace,
          source: operationName ?? 'FirstSuccess',
          context: {'operationIndex': i, 'totalOperations': operations.length},
        );
      }
    }

    // All operations failed
    return Result.failure(
      AppError(
        code: 'ALL_OPERATIONS_FAILED',
        message: 'All ${operations.length} operations failed',
        details: operationName,
        context: {'errors': errors.length},
        severity: ErrorSeverity.error,
      ),
    );
  }

  /// Wrap a synchronous operation in a Result
  static Result<T, AppError> tryCatch<T>(
    T Function() operation, {
    String? operationName,
    Map<String, dynamic>? context,
  }) {
    try {
      return Result.success(operation());
    } catch (e, stackTrace) {
      logError(
        e,
        stackTrace: stackTrace,
        source: operationName,
        context: context,
      );
      return Result.failure(_toAppError(e, stackTrace));
    }
  }

  /// Wrap an async operation in a Result
  static Future<Result<T, AppError>> tryCatchAsync<T>(
    Future<T> Function() operation, {
    String? operationName,
    Map<String, dynamic>? context,
  }) async {
    try {
      final result = await operation();
      return Result.success(result);
    } catch (e, stackTrace) {
      logError(
        e,
        stackTrace: stackTrace,
        source: operationName,
        context: context,
      );
      return Result.failure(_toAppError(e, stackTrace));
    }
  }

  /// Convert any error to AppError
  static AppError _toAppError(dynamic error, StackTrace? stackTrace) {
    if (error is AppError) {
      return error;
    }

    if (error is TimeoutException) {
      return NetworkError.timeout(details: error.message);
    }

    return AppError.fromException(
      error is Exception ? error : Exception(error.toString()),
      stackTrace: stackTrace,
    );
  }
}

/// Circuit breaker pattern for preventing cascading failures
class CircuitBreaker {
  final String name;
  final int failureThreshold;
  final Duration timeout;
  final Duration resetTimeout;

  CircuitBreakerState _state = CircuitBreakerState.closed;
  int _failureCount = 0;
  DateTime? _lastFailureTime;

  CircuitBreaker({
    required this.name,
    this.failureThreshold = 5,
    this.timeout = const Duration(seconds: 30),
    this.resetTimeout = const Duration(minutes: 1),
  });

  CircuitBreakerState get state => _state;
  int get failureCount => _failureCount;

  /// Execute operation with circuit breaker
  Future<Result<T, AppError>> execute<T>(
    Future<T> Function() operation,
  ) async {
    // Check if circuit is open
    if (_state == CircuitBreakerState.open) {
      if (_shouldAttemptReset()) {
        _state = CircuitBreakerState.halfOpen;
      } else {
        return Result.failure(
          AppError(
            code: 'CIRCUIT_BREAKER_OPEN',
            message: 'Circuit breaker is open for $name',
            details: 'Too many failures detected. Try again later.',
            severity: ErrorSeverity.warning,
            isRecoverable: true,
            recoveryAction: 'Wait for ${resetTimeout.inSeconds} seconds and try again',
          ),
        );
      }
    }

    try {
      final result = await operation().timeout(timeout);
      _onSuccess();
      return Result.success(result);
    } catch (e, stackTrace) {
      _onFailure();
      logError(
        e,
        stackTrace: stackTrace,
        source: 'CircuitBreaker:$name',
        context: {
          'state': _state.toString(),
          'failureCount': _failureCount,
        },
      );
      return Result.failure(ErrorRecovery._toAppError(e, stackTrace));
    }
  }

  bool _shouldAttemptReset() {
    if (_lastFailureTime == null) return false;
    return DateTime.now().difference(_lastFailureTime!) > resetTimeout;
  }

  void _onSuccess() {
    _failureCount = 0;
    _state = CircuitBreakerState.closed;
    _lastFailureTime = null;
  }

  void _onFailure() {
    _failureCount++;
    _lastFailureTime = DateTime.now();

    if (_failureCount >= failureThreshold) {
      _state = CircuitBreakerState.open;
    }
  }

  /// Reset the circuit breaker
  void reset() {
    _failureCount = 0;
    _state = CircuitBreakerState.closed;
    _lastFailureTime = null;
  }
}

enum CircuitBreakerState {
  closed, // Normal operation
  open, // Failures exceeded threshold
  halfOpen, // Testing if service recovered
}
