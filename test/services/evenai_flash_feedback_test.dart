// WS-D fix #4: _flashFeedback used to unconditionally push screen 0x00
// after its 500 ms dismiss, which kicked a live-listening session back
// to the firmware's stock dashboard and looked to the user like a
// factory reset. The fix restores the screen implied by the current
// HUD intent instead. This test pins the mapping via the pure
// `restoreScreenIdForIntent` helper exposed @visibleForTesting.

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_helix/services/evenai.dart';
import 'package:flutter_helix/services/hud_intent.dart';

void main() {
  group('EvenAI.restoreScreenIdForIntent (WS-D fix #4)', () {
    test('liveListening restores the EvenAI overlay (0x01), not hide (0x00)',
        () {
      expect(
        EvenAI.restoreScreenIdForIntent(HudIntent.liveListening),
        0x01,
      );
    });

    test('textTransfer restores the EvenAI overlay (0x01)', () {
      expect(
        EvenAI.restoreScreenIdForIntent(HudIntent.textTransfer),
        0x01,
      );
    });

    test('idle/quickAsk/dashboard/notification dismiss to 0x00', () {
      expect(EvenAI.restoreScreenIdForIntent(HudIntent.idle), 0x00);
      expect(EvenAI.restoreScreenIdForIntent(HudIntent.quickAsk), 0x00);
      expect(EvenAI.restoreScreenIdForIntent(HudIntent.dashboard), 0x00);
      expect(EvenAI.restoreScreenIdForIntent(HudIntent.notification), 0x00);
    });
  });
}
