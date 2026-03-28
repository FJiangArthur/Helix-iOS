import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_helix/services/conversation_engine.dart';
import 'package:flutter_helix/services/hud_controller.dart';
import 'package:flutter_helix/services/settings_manager.dart';

import '../helpers/test_helpers.dart';
import '../helpers/stream_recorder.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ConversationEngine engine;
  late FakeJsonProvider provider;
  late StreamRecorder recorder;

  setUpAll(() => installPlatformMocks());
  tearDownAll(() => removePlatformMocks());

  setUp(() async {
    final result = await setupTestEngine();
    engine = result.engine;
    provider = result.provider;
    recorder = StreamRecorder(engine);
  });

  tearDown(() {
    recorder.dispose();
    teardownTestEngine(engine);
  });

  group('B2 - Interview mode STAR coaching', () {
    test('behavioral question triggers STAR coaching prompt', () async {
      engine.start(mode: ConversationMode.interview);
      engine.autoDetectQuestions = false;

      final coachingFuture = waitForStream<CoachingPrompt>(
        engine.coachingStream,
        timeout: const Duration(seconds: 3),
      );

      // "Tell me about a time" matches the behavioral pattern regex
      engine.onTranscriptionFinalized(
        'Tell me about a time you led a cross-functional team',
      );

      final coaching = await coachingFuture;
      expect(coaching.framework, 'STAR');
      expect(coaching.steps.length, 4);
      expect(coaching.steps[0], contains('Situation'));
      expect(coaching.questionContext, contains('Tell me about a time'));
    });

    test('non-behavioral question does NOT trigger coaching', () async {
      engine.start(mode: ConversationMode.interview);
      engine.autoDetectQuestions = false;

      // Ordinary question — should not match behavioral patterns
      engine.onTranscriptionFinalized('What is your salary expectation?');
      await Future<void>.delayed(const Duration(milliseconds: 200));

      expect(recorder.coachingPrompts, isEmpty);
    });
  });

  group('B3 - Passive mode', () {
    test('no auto-detection in passive mode', () async {
      engine.autoDetectQuestions = true;
      engine.start(mode: ConversationMode.passive);

      engine.onTranscriptionFinalized(
        'What do you think about artificial intelligence?',
      );
      await Future<void>.delayed(const Duration(milliseconds: 300));

      // In passive mode, question detection should not fire
      expect(recorder.questionDetections, isEmpty);
    });

    test('manual askQuestion still works in passive mode', () async {
      engine.start(mode: ConversationMode.passive);
      provider.enqueueStreamResponse(
        const FakeStreamResponse(['AI is fascinating.']),
      );

      await engine.askQuestion('What is AI?');
      await Future<void>.delayed(const Duration(milliseconds: 200));

      expect(engine.history, isNotEmpty);
      final lastTurn = engine.history.last;
      expect(lastTurn.content, contains('AI'));
    });
  });

  group('B13 - Mode switching preserves history', () {
    test('switching from general to interview preserves turns', () async {
      // General mode Q&A
      engine.start(mode: ConversationMode.general);
      provider.enqueueStreamResponse(
        const FakeStreamResponse(['General answer.']),
      );
      await engine.askQuestion('General question?');
      await Future<void>.delayed(const Duration(milliseconds: 200));

      final historyAfterGeneral = engine.history.length;
      expect(historyAfterGeneral, greaterThan(0));

      // Switch to interview mode
      engine.setMode(ConversationMode.interview);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      // History should be preserved
      expect(engine.history.length, historyAfterGeneral);
      expect(engine.mode, ConversationMode.interview);
    });
  });
}
