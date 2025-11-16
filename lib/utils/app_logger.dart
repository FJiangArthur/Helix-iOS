import 'package:logger/logger.dart';

/// Global logger instance for the application
///
/// Usage:
/// ```dart
/// import 'package:flutter_helix/utils/app_logger.dart';
///
/// appLogger.d('Debug message');
/// appLogger.i('Info message');
/// appLogger.w('Warning message');
/// appLogger.e('Error message', error: error, stackTrace: stackTrace);
/// ```
final Logger appLogger = Logger(
  printer: PrettyPrinter(
    methodCount: 2,
    errorMethodCount: 8,
    lineLength: 120,
    colors: true,
    printEmojis: true,
    dateTimeFormat: DateTimeFormat.onlyTimeAndSinceStart,
  ),
  level: Level.debug, // Change to Level.info for production
);

/// Simplified logger for production builds
final Logger appLoggerSimple = Logger(
  printer: SimplePrinter(
    colors: false,
    printTime: true,
  ),
  level: Level.info,
);
