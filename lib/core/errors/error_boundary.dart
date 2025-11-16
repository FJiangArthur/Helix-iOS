/// Error boundary widgets for graceful error handling in UI

import 'package:flutter/material.dart';
import 'app_error.dart';
import 'error_formatter.dart';
import 'error_logger.dart';

/// Error boundary widget that catches and displays errors gracefully
class ErrorBoundary extends StatefulWidget {
  final Widget child;
  final Widget Function(BuildContext, AppError)? errorBuilder;
  final void Function(dynamic, StackTrace)? onError;
  final bool showErrorDetails;

  const ErrorBoundary({
    super.key,
    required this.child,
    this.errorBuilder,
    this.onError,
    this.showErrorDetails = false,
  });

  @override
  State<ErrorBoundary> createState() => _ErrorBoundaryState();

  /// Create error boundary with custom error widget
  static Widget withCustomError({
    required Widget child,
    required Widget Function(BuildContext, AppError) errorBuilder,
    void Function(dynamic, StackTrace)? onError,
  }) {
    return ErrorBoundary(
      errorBuilder: errorBuilder,
      onError: onError,
      child: child,
    );
  }

  /// Create error boundary with default error widget
  static Widget withDefaultError({
    required Widget child,
    void Function(dynamic, StackTrace)? onError,
    bool showErrorDetails = false,
  }) {
    return ErrorBoundary(
      onError: onError,
      showErrorDetails: showErrorDetails,
      child: child,
    );
  }
}

class _ErrorBoundaryState extends State<ErrorBoundary> {
  AppError? _error;

  @override
  void initState() {
    super.initState();
    // Set up Flutter error handler
    FlutterError.onError = (FlutterErrorDetails details) {
      _handleError(details.exception, details.stack ?? StackTrace.current);
    };
  }

  void _handleError(dynamic error, StackTrace stackTrace) {
    // Log the error
    logError(error, stackTrace: stackTrace, source: 'ErrorBoundary');

    // Call custom error handler if provided
    widget.onError?.call(error, stackTrace);

    // Convert to AppError if needed
    final appError = error is AppError
        ? error
        : AppError.fromException(
            error is Exception ? error : Exception(error.toString()),
            stackTrace: stackTrace,
          );

    // Update state to show error
    if (mounted) {
      setState(() {
        _error = appError;
      });
    }
  }

  void _resetError() {
    setState(() {
      _error = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      if (widget.errorBuilder != null) {
        return widget.errorBuilder!(context, _error!);
      }
      return DefaultErrorWidget(
        error: _error!,
        onRetry: _resetError,
        showDetails: widget.showErrorDetails,
      );
    }

    return widget.child;
  }
}

/// Default error display widget
class DefaultErrorWidget extends StatelessWidget {
  final AppError error;
  final VoidCallback? onRetry;
  final bool showDetails;

  const DefaultErrorWidget({
    super.key,
    required this.error,
    this.onRetry,
    this.showDetails = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Error icon
            Text(
              ErrorFormatter.getCategoryIcon(error.category),
              style: const TextStyle(fontSize: 64),
            ),
            const SizedBox(height: 16),

            // Error message
            Text(
              error.message,
              style: theme.textTheme.titleLarge?.copyWith(
                color: _getSeverityColor(error.severity),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),

            // Error details
            if (error.details != null)
              Text(
                error.details!,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.textTheme.bodySmall?.color,
                ),
                textAlign: TextAlign.center,
              ),
            const SizedBox(height: 16),

            // Recovery action
            if (error.recoveryAction != null)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.info_outline, size: 20),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        error.recoveryAction!,
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 24),

            // Retry button
            if (error.isRecoverable && onRetry != null)
              ElevatedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),

            // Error details (development mode)
            if (showDetails) ...[
              const SizedBox(height: 24),
              ExpansionTile(
                title: const Text('Error Details'),
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    width: double.infinity,
                    child: SelectableText(
                      error.getDeveloperMessage(),
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Color _getSeverityColor(ErrorSeverity severity) {
    switch (severity) {
      case ErrorSeverity.debug:
      case ErrorSeverity.info:
        return Colors.blue;
      case ErrorSeverity.warning:
        return Colors.orange;
      case ErrorSeverity.error:
        return Colors.red;
      case ErrorSeverity.critical:
      case ErrorSeverity.fatal:
        return Colors.red.shade900;
    }
  }
}

/// Error snackbar for showing transient errors
class ErrorSnackbar {
  static void show(
    BuildContext context,
    dynamic error, {
    Duration duration = const Duration(seconds: 4),
    SnackBarAction? action,
  }) {
    final appError = error is AppError
        ? error
        : AppError.fromException(
            error is Exception ? error : Exception(error.toString()),
          );

    final message = ErrorFormatter.formatForUser(error);
    final icon = ErrorFormatter.getCategoryIcon(appError.category);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Text(icon, style: const TextStyle(fontSize: 20)),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        duration: duration,
        action: action ??
            (appError.isRecoverable
                ? SnackBarAction(
                    label: 'Dismiss',
                    onPressed: () {
                      ScaffoldMessenger.of(context).hideCurrentSnackBar();
                    },
                  )
                : null),
        backgroundColor: _getSeverityColor(appError.severity),
      ),
    );
  }

  static Color _getSeverityColor(ErrorSeverity severity) {
    switch (severity) {
      case ErrorSeverity.debug:
      case ErrorSeverity.info:
        return Colors.blue.shade700;
      case ErrorSeverity.warning:
        return Colors.orange.shade700;
      case ErrorSeverity.error:
        return Colors.red.shade700;
      case ErrorSeverity.critical:
      case ErrorSeverity.fatal:
        return Colors.red.shade900;
    }
  }
}

/// Error dialog for showing errors that require user attention
class ErrorDialog {
  static Future<void> show(
    BuildContext context,
    dynamic error, {
    VoidCallback? onRetry,
    bool showDetails = false,
  }) async {
    final appError = error is AppError
        ? error
        : AppError.fromException(
            error is Exception ? error : Exception(error.toString()),
          );

    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        icon: Text(
          ErrorFormatter.getCategoryIcon(appError.category),
          style: const TextStyle(fontSize: 48),
        ),
        title: Text(appError.message),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (appError.details != null) Text(appError.details!),
            if (appError.recoveryAction != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        appError.recoveryAction!,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (showDetails && appError.context != null) ...[
              const SizedBox(height: 16),
              ExpansionTile(
                title: const Text('Details'),
                children: [
                  Text(
                    appError.getDeveloperMessage(),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontFamily: 'monospace',
                        ),
                  ),
                ],
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Dismiss'),
          ),
          if (appError.isRecoverable && onRetry != null)
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                onRetry();
              },
              child: const Text('Retry'),
            ),
        ],
      ),
    );
  }
}

/// Extension for BuildContext to easily show errors
extension ErrorDisplayExtension on BuildContext {
  /// Show error as snackbar
  void showErrorSnackbar(
    dynamic error, {
    Duration duration = const Duration(seconds: 4),
  }) {
    ErrorSnackbar.show(this, error, duration: duration);
  }

  /// Show error as dialog
  Future<void> showErrorDialog(
    dynamic error, {
    VoidCallback? onRetry,
    bool showDetails = false,
  }) {
    return ErrorDialog.show(
      this,
      error,
      onRetry: onRetry,
      showDetails: showDetails,
    );
  }
}
