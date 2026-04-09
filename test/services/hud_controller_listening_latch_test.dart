// WS-J: HudController stabilises the liveListening indicator during a
// stream chunk race. Any transition away from liveListening within the
// 500ms stable window is latched (deferred); a re-entry to liveListening
// during that window cancels the pending leave so the indicator never
// flashes.

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_helix/services/hud_controller.dart';
import 'package:flutter_helix/services/hud_intent.dart';

void main() {
  group('HudController WS-J liveListening stability latch', () {
    final controller = HudController.instance;

    setUp(() {
      controller.resetLiveListeningLatchForTest();
    });

    test(
        'leave-then-reenter within 500ms window does not flash the indicator',
        () async {
      final events = <HudIntent>[];
      final sub = controller.intentStream.listen((r) => events.add(r.intent));

      // Enter liveListening (no screen push so BLE stub not needed).
      await controller.transitionTo(
        HudIntent.liveListening,
        source: 'test.enterLive',
      );
      expect(controller.currentIntent, HudIntent.liveListening);

      // Simulate stream chunk race: code briefly asks to leave, then
      // re-enters liveListening within the 500ms window. The latch must
      // suppress the leave entirely.
      await controller.transitionTo(
        HudIntent.textTransfer,
        source: 'test.leave1',
      );
      // Intent must still be liveListening — leave is latched, not applied.
      expect(controller.currentIntent, HudIntent.liveListening);

      await Future<void>.delayed(const Duration(milliseconds: 50));
      await controller.transitionTo(
        HudIntent.liveListening,
        source: 'test.reenter',
      );

      // Now wait past the latch window. The pending leave should have
      // been cancelled by the re-entry.
      await Future<void>.delayed(const Duration(milliseconds: 600));

      expect(
        controller.currentIntent,
        HudIntent.liveListening,
        reason: 'Latch must suppress the flash during the 500ms window',
      );
      // No textTransfer event should ever have been emitted.
      expect(
        events.where((e) => e == HudIntent.textTransfer).isEmpty,
        isTrue,
        reason: 'Latched leave must not emit a transient textTransfer event',
      );

      await sub.cancel();
    });

    test(
        'leave without re-entry is applied after the 500ms stable window',
        () async {
      await controller.transitionTo(
        HudIntent.liveListening,
        source: 'test.enterLive2',
      );
      expect(controller.currentIntent, HudIntent.liveListening);

      await controller.transitionTo(
        HudIntent.textTransfer,
        source: 'test.leaveOnly',
      );
      // Still liveListening — the leave is latched.
      expect(controller.currentIntent, HudIntent.liveListening);

      // Wait for the latch window to expire + a small margin.
      await Future<void>.delayed(const Duration(milliseconds: 600));

      // The deferred transition should now have fired.
      expect(controller.currentIntent, HudIntent.textTransfer);
    });

    test('leave after the stable window is applied immediately', () async {
      await controller.transitionTo(
        HudIntent.liveListening,
        source: 'test.enterLive3',
      );
      // Let the stable window pass before the leave request.
      await Future<void>.delayed(const Duration(milliseconds: 520));

      await controller.transitionTo(
        HudIntent.textTransfer,
        source: 'test.lateLeave',
      );
      expect(controller.currentIntent, HudIntent.textTransfer);
    });

    test(
        'multiple rapid leave attempts keep coalescing — only the latest is queued',
        () async {
      await controller.transitionTo(
        HudIntent.liveListening,
        source: 'test.enterLive4',
      );

      await controller.transitionTo(
        HudIntent.textTransfer,
        source: 'test.l1',
      );
      await controller.transitionTo(
        HudIntent.quickAsk,
        source: 'test.l2',
      );
      await controller.transitionTo(
        HudIntent.notification,
        source: 'test.l3',
      );

      // Still latched on liveListening.
      expect(controller.currentIntent, HudIntent.liveListening);

      await Future<void>.delayed(const Duration(milliseconds: 600));
      // The most recent pending leave wins.
      expect(controller.currentIntent, HudIntent.notification);
    });
  });
}
