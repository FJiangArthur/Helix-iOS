// WS-B Fix 3 regression test: the CONVERSATION HUB card should remain
// visible across transient mid-session stream glitches and should not
// collapse to the LOADOUT placeholder once a session has gone live.
//
// NOTE: the `_liveCardLatched` latch is flipped from `recordingStateStream`
// events, which are produced by the `RecordingCoordinator` singleton behind
// platform channels. The WS-B fix agent's file allowlist excludes
// `recording_coordinator.dart`, so we cannot drive the latch directly from
// a widget test. Instead, this test covers the *closest observable
// behavior* available via the engine's public API: once the live session
// has emitted a transcript, a subsequent empty snapshot (which is exactly
// what a mid-session `start()` re-entry previously emitted before Fix 1)
// must NOT collapse the CONVERSATION HUB card to the LOADOUT placeholder
// while the engine is still active.
//
// The dedicated latch behavior (Fix 3) is additionally exercised by
// the engine-level regression tests in
// `test/services/conversation_engine_test.dart` ("WS-B:" tests).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_helix/screens/home_screen.dart';
import 'package:flutter_helix/services/conversation_engine.dart';
import 'package:flutter_helix/services/settings_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await SettingsManager.instance.initialize();
    ConversationEngine.resetTestHooks();
    SettingsManager.instance.assistantProfileId = 'general';
    SettingsManager.instance.language = 'en';
    SettingsManager.instance.autoDetectQuestions = false;
    ConversationEngine.instance.clearHistory(force: true);
    ConversationEngine.instance.stop();
  });

  testWidgets(
    'WS-B: HUB card remains non-loadout after transient empty snapshot mid-session',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: HomeScreen())),
      );
      await tester.pump();

      // Initially there is no live session -> LOADOUT placeholder visible.
      expect(
        find.byKey(const Key('home-session-loadout-card')),
        findsOneWidget,
      );

      final engine = ConversationEngine.instance;
      engine.start(source: TranscriptSource.phone);
      engine.onTranscriptionFinalized('Mid-session transcript segment');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 30));

      // Live card is now visible; LOADOUT is gone.
      expect(
        find.byKey(const Key('home-session-loadout-card')),
        findsNothing,
      );

      // Simulate the pre-Fix 1 blanking scenario: a mid-session start()
      // re-entry. With Fix 1, the engine must NOT wipe the live transcript
      // or emit an empty aiResponse, and the HUB card must remain visible.
      engine.start(source: TranscriptSource.phone);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 30));

      expect(
        find.byKey(const Key('home-session-loadout-card')),
        findsNothing,
        reason:
            'CONVERSATION HUB card must stay live across mid-session start() '
            're-entry (WS-B Fix 1 + Fix 3).',
      );

      // Simulate clearHistory() fired from the History tab mid-session:
      // Fix 2 must preserve the live transcript so the card stays visible.
      engine.clearHistory();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 30));

      expect(
        find.byKey(const Key('home-session-loadout-card')),
        findsNothing,
        reason:
            'CONVERSATION HUB card must stay live across mid-session '
            'clearHistory() (WS-B Fix 2).',
      );

      engine.stop();
      await tester.pump();
    },
  );
}
