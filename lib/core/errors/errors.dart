/// Error handling library for the application
///
/// This library provides comprehensive error handling utilities including:
/// - Standardized error types and codes
/// - Error formatting and logging
/// - Error recovery strategies
/// - Error boundary widgets for UI
///
/// Usage:
/// ```dart
/// import 'package:flutter_helix/core/errors/errors.dart';
///
/// // Throw a specific error
/// throw NetworkError.noConnection();
///
/// // Use Result type for safer error handling
/// final result = await ErrorRecovery.tryCatchAsync(() async {
///   return await apiService.fetchData();
/// });
///
/// result.fold(
///   (data) => print('Success: $data'),
///   (error) => print('Error: $error'),
/// );
///
/// // Log errors with context
/// logError(error, stackTrace: stackTrace, context: {'userId': userId});
///
/// // Show errors in UI
/// context.showErrorSnackbar(error);
/// ```

export 'app_error.dart';
export 'error_formatter.dart';
export 'error_logger.dart';
export 'error_recovery.dart';
export 'error_boundary.dart';
