import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_helix/services/conversation_engine.dart';
import 'package:flutter_helix/services/prompt_assembler.dart';
import 'package:flutter_helix/services/session_prep_service.dart';
import 'package:flutter_helix/services/settings_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/test_helpers.dart';

/// Integration tests for the end-to-end Session Prep lifecycle.
///
/// These tests wire SessionPrepService + PromptAssembler + ConversationEngine
/// together using the existing FakeJsonProvider test harness. They verify
/// the three critical flows from the test-plan artifact:
///
///   1. Paste → save → simulated app restart restores prep.
///   2. Load prep → conversation save event fires → prep cleared for next
///      conversation (conversation-end boundary).
///   3. Feature flag off → prep is NOT injected even if loaded.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() => installPlatformMocks());
  tearDownAll(() => removePlatformMocks());

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await SessionPrepService.instance.debugReset();
  });

  tearDown(() async {
    await SessionPrepService.instance.debugReset();
  });

  group('Integration: paste → restart', () {
    test('prep written in session N is visible in session N+1', () async {
      // Session N: fresh, save prep.
      await SettingsManager.instance.initialize();
      SettingsManager.instance.sessionPrepEnabled = true;
      await SessionPrepService.instance.initialize();
      final result =
          await SessionPrepService.instance.save('Prepare for interview Q&A');
      expect(result, SaveResult.saved);

      // Verify the raw SharedPreferences holds it.
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('sessionPrep'), 'Prepare for interview Q&A');

      // Session N+1: simulate cold start by resetting the singleton's
      // in-memory state but keeping SharedPreferences intact.
      await SessionPrepService.instance.debugReset();
      await SessionPrepService.instance.initialize();
      expect(SessionPrepService.instance.prep, 'Prepare for interview Q&A',
          reason: 'prep should rehydrate from SharedPreferences');
    });
  });

  group('Integration: conversation-end boundary', () {
    test(
      'sessionSavedStream event clears prep so next conversation is uncontaminated',
      () async {
        await SettingsManager.instance.initialize();
        SettingsManager.instance.sessionPrepEnabled = true;
        await SessionPrepService.instance.initialize();
        await SessionPrepService.instance.save('Interview prep about Rust');
        expect(SessionPrepService.instance.prep.isNotEmpty, isTrue);

        // Set up the engine enough that its sessionSavedStream is available.
        final setup = await setupTestEngine();
        // Re-subscribe after setupTestEngine which likely reset state.
        await SessionPrepService.instance.debugReset();
        // Restore the persisted prep for this test.
        SharedPreferences.setMockInitialValues({
          'sessionPrep': 'Interview prep about Rust',
          'sessionPrepEnabled': true,
        });
        await SettingsManager.instance.initialize();
        await SessionPrepService.instance.initialize();
        expect(SessionPrepService.instance.prep, 'Interview prep about Rust');

        // Mimic a conversation-save event firing.
        setup.engine.debugEmitSessionSaved('test-conversation-id');

        // Let the async listener run.
        await Future<void>.delayed(const Duration(milliseconds: 50));

        expect(
          SessionPrepService.instance.prep,
          isEmpty,
          reason: 'conversation save should auto-clear prep',
        );

        teardownTestEngine(setup.engine);
      },
      timeout: const Timeout(Duration(seconds: 15)),
    );
  });

  group('Integration: feature flag off', () {
    test('flag=false → prompt assembler omits prep entirely', () async {
      await SettingsManager.instance.initialize();
      SettingsManager.instance.sessionPrepEnabled = false;
      await SessionPrepService.instance.initialize();
      await SessionPrepService.instance.save('Confidential prep');
      expect(SessionPrepService.instance.prep, 'Confidential prep');

      final prompt =
          PromptAssembler.assembleSystemPrompt('You are helpful.');
      expect(prompt, 'You are helpful.',
          reason: 'disabled flag must suppress injection even when loaded');
      expect(prompt.contains('Confidential'), isFalse);
    });

    test(
        'flag=true with empty prep → assembler still returns base prompt unchanged',
        () async {
      await SettingsManager.instance.initialize();
      SettingsManager.instance.sessionPrepEnabled = true;
      await SessionPrepService.instance.initialize();
      // No save — prep stays empty.
      final prompt =
          PromptAssembler.assembleSystemPrompt('You are helpful.');
      expect(prompt, 'You are helpful.');
    });
  });
}
