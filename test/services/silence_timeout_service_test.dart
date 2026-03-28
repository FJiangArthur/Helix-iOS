import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_helix/services/silence_timeout_service.dart';

void main() {
  late SilenceTimeoutService service;

  setUp(() {
    // Reset singleton for clean state
    SilenceTimeoutService.instance.dispose();
    service = SilenceTimeoutService.instance;
  });

  tearDown(() {
    service.stop();
  });

  group('D6 - SilenceTimeout fires after configured duration', () {
    test('timeout fires when no activity detected', () async {
      final completer = Completer<void>();
      service.onSilenceTimeout.listen((_) {
        if (!completer.isCompleted) completer.complete();
      });

      service.start(timeout: const Duration(milliseconds: 100));

      await completer.future.timeout(
        const Duration(seconds: 2),
        onTimeout: () => fail('Silence timeout did not fire'),
      );
    });
  });

  group('D7 - Activity resets timer', () {
    test('calling onActivity resets the timeout', () async {
      var timeoutCount = 0;
      service.onSilenceTimeout.listen((_) => timeoutCount++);

      // Start with 150ms timeout
      service.start(timeout: const Duration(milliseconds: 150));

      // At 100ms, call onActivity — should reset timer
      await Future<void>.delayed(const Duration(milliseconds: 100));
      service.onActivity();

      // At 200ms from start (100ms after reset), timeout should NOT have fired
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(timeoutCount, 0);

      // Wait for remaining 50ms + buffer — now it should fire
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(timeoutCount, 1);
    });

    test('stop prevents timeout from firing', () async {
      var timeoutCount = 0;
      service.onSilenceTimeout.listen((_) => timeoutCount++);

      service.start(timeout: const Duration(milliseconds: 50));
      service.stop();

      await Future<void>.delayed(const Duration(milliseconds: 150));
      expect(timeoutCount, 0);
    });
  });
}
