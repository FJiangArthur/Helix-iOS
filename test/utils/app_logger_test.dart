import 'package:flutter_helix/utils/app_logger.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logger/logger.dart';

void main() {
  group('resolveAppLogSettings', () {
    test('uses verbose logging for non-release builds by default', () {
      final settings = resolveAppLogSettings(isReleaseMode: false);

      expect(settings.allowContentLogs, isTrue);
      expect(settings.usePrettyPrinter, isTrue);
      expect(settings.level, Level.debug);
    });

    test('uses sanitized logging for release builds', () {
      final settings = resolveAppLogSettings(isReleaseMode: true);

      expect(settings.allowContentLogs, isFalse);
      expect(settings.usePrettyPrinter, isFalse);
      expect(settings.level, Level.warning);
    });

    test('allows non-release builds to force sanitized logging', () {
      final settings = resolveAppLogSettings(
        isReleaseMode: false,
        forceSanitizedLogs: true,
      );

      expect(settings.allowContentLogs, isFalse);
      expect(settings.usePrettyPrinter, isFalse);
      expect(settings.level, Level.warning);
    });
  });
}
