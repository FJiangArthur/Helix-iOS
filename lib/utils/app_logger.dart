import 'dart:developer' as developer;
import 'dart:io' show stderr;

import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';

class AppLogSettings {
  const AppLogSettings({
    required this.allowContentLogs,
    required this.level,
    required this.usePrettyPrinter,
  });

  final bool allowContentLogs;
  final Level level;
  final bool usePrettyPrinter;
}

const bool _forceSanitizedLogs = bool.fromEnvironment(
  'HELIX_FORCE_SANITIZED_LOGS',
);

AppLogSettings resolveAppLogSettings({
  bool isReleaseMode = kReleaseMode,
  bool forceSanitizedLogs = _forceSanitizedLogs,
}) {
  final sanitizeLogs = isReleaseMode || forceSanitizedLogs;
  return AppLogSettings(
    allowContentLogs: !sanitizeLogs,
    level: sanitizeLogs ? Level.warning : Level.debug,
    usePrettyPrinter: !sanitizeLogs,
  );
}

final AppLogSettings _appLogSettings = resolveAppLogSettings();

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
final appLogger = Logger(
  printer: _appLogSettings.usePrettyPrinter
      ? PrettyPrinter(
          methodCount: 2,
          errorMethodCount: 8,
          lineLength: 120,
          colors: true,
          printEmojis: true,
          dateTimeFormat: DateTimeFormat.onlyTimeAndSinceStart,
        )
      : SimplePrinter(colors: false, printTime: true),
  level: _appLogSettings.level,
);

/// Emit a high-signal diagnostic line that is visible in device console logs.
///
/// This bypasses the normal release log filtering used by [appLogger] so
/// transport failures can still be captured from physical-device syslog.
void emitDeviceDiagnostic(String tag, String message) {
  final line = '[$tag] $message';
  developer.log(line, name: 'Helix');
  stderr.writeln(line);
}
