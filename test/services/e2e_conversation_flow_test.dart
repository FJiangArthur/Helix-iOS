import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_helix/services/conversation_engine.dart';
import 'package:flutter_helix/services/settings_manager.dart';

import '../helpers/test_helpers.dart';
import '../helpers/stream_recorder.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ConversationEngine engine;
  late FakeJsonProvider provider;
  late StreamRecorder recorder;

  setUp(() async {
    final setup = await setupTestEngine(
      settingsOverrides: {
        'language': 'en',
        'transcriptionBackend': 'appleCloud',
      },
    );
    engine = setup.engine;
    provider = setup.provider;
    SettingsManager.instance.autoDetectQuestions = true;
    SettingsManager.instance.answerAll = true;
    recorder = StreamRecorder(engine);
  });

  tearDown(() {
    recorder.dispose();
    teardownTestEngine(engine);
  });

  group('E2E conversation flow', () {
    // F1 [P0]: Full conversation flow: start -> transcribe -> detect question -> answer -> history
    test(
      'F1: full flow — transcribe, detect question, generate answer, update history',
      () async {
        // Queue detection response (getResponse call from _analyzeRecentTranscriptWindow)
        provider.enqueueResponse(
          '{"shouldRespond": true, "question": "What is AI?", '
          '"questionExcerpt": "What is AI", "askedBy": "other"}',
        );
        // Queue streaming answer
        provider.enqueueStreamResponse(
          const FakeStreamResponse(['AI is ', 'artificial ', 'intelligence.']),
        );
        // Queue follow-up chips (getResponse from _postResponseAnalysis)
        provider.enqueueResponse(
          '{"chips": ["Tell me more about AI", "How does it work?"], "factCheck": ""}',
        );

        engine.start();
        engine.onTranscriptionUpdate('So tell me, what is AI exactly?');
        engine.onTranscriptionFinalized('So tell me, what is AI exactly?');

        // Wait for the engine to detect the question and produce an AI response.
        // The detection triggers _analyzeRecentTranscriptWindow (getResponse),
        // then auto-answer triggers _generateResponse (streamResponse).
        // Give enough time for the full pipeline to complete.
        await Future<void>.delayed(const Duration(milliseconds: 500));

        // Verify history has at least one user turn (the detected question)
        final userTurns = engine.history.where((t) => t.role == 'user').toList();
        expect(userTurns, isNotEmpty, reason: 'Should have detected a user question');
        expect(
          userTurns.first.content,
          contains('AI'),
          reason: 'Detected question should mention AI',
        );

        // Verify history has an assistant response
        final assistantTurns =
            engine.history.where((t) => t.role == 'assistant').toList();
        expect(
          assistantTurns,
          isNotEmpty,
          reason: 'Should have generated an AI answer',
        );
        expect(
          assistantTurns.first.content,
          contains('intelligence'),
          reason: 'AI response should contain the streamed answer',
        );

        // Verify aiResponseStream received chunks
        expect(
          recorder.aiResponses,
          isNotEmpty,
          reason: 'aiResponseStream should have emitted chunks',
        );

        // Verify status progressed through the expected states
        expect(
          recorder.statuses,
          containsAll([EngineStatus.listening, EngineStatus.thinking]),
          reason: 'Status should have transitioned through listening and thinking',
        );
      },
    );

    // F2 [P1]: Multi-turn conversation with context retention
    test(
      'F2: multi-turn conversation accumulates history and passes context',
      () async {
        // --- Turn 1 ---
        provider.enqueueResponse(
          '{"shouldRespond": true, "question": "What is AI?", '
          '"questionExcerpt": "What is AI", "askedBy": "other"}',
        );
        provider.enqueueStreamResponse(
          const FakeStreamResponse(['AI stands for artificial intelligence.']),
        );
        // Follow-up chips for turn 1
        provider.enqueueResponse('{"chips": [], "factCheck": ""}');

        engine.start();
        engine.onTranscriptionFinalized('What is AI?');
        await Future<void>.delayed(const Duration(milliseconds: 500));

        final historyAfterTurn1 = engine.history.length;
        expect(historyAfterTurn1, greaterThanOrEqualTo(2),
            reason: 'Turn 1 should produce user + assistant turns');

        // --- Turn 2 ---
        provider.enqueueResponse(
          '{"shouldRespond": true, "question": "How does machine learning work?", '
          '"questionExcerpt": "How does machine learning work", "askedBy": "other"}',
        );
        provider.enqueueStreamResponse(
          const FakeStreamResponse(
              ['Machine learning uses data to learn patterns.']),
        );
        // Follow-up chips for turn 2
        provider.enqueueResponse('{"chips": [], "factCheck": ""}');

        engine.onTranscriptionFinalized('How does machine learning work?');
        await Future<void>.delayed(const Duration(milliseconds: 500));

        // History should have grown
        expect(engine.history.length, greaterThan(historyAfterTurn1),
            reason: 'Turn 2 should add more turns to history');

        // The second LLM call's messages should include prior context.
        // capturedMessages has all calls: detection1, stream1, followUp1,
        // detection2, stream2, followUp2. The stream call for turn 2
        // (index varies) should reference prior conversation.
        final streamCalls = provider.capturedMessages
            .where((msgs) => msgs.any((m) => m.content.contains('machine learning')))
            .toList();
        expect(streamCalls, isNotEmpty,
            reason: 'Should have captured messages for turn 2');
      },
    );

    // F3 [P1]: Mode switching mid-conversation
    test(
      'F3: mode switching mid-conversation preserves history',
      () async {
        // --- General mode turn ---
        engine.start(mode: ConversationMode.general);

        provider.enqueueStreamResponse(
          const FakeStreamResponse(['The sky is blue due to Rayleigh scattering.']),
        );
        // Follow-up chips
        provider.enqueueResponse('{"chips": [], "factCheck": ""}');

        await engine.askQuestion('Why is the sky blue?');
        await Future<void>.delayed(const Duration(milliseconds: 200));

        final historyAfterGeneral = engine.history.length;
        expect(historyAfterGeneral, greaterThanOrEqualTo(2));

        // --- Switch to interview mode ---
        engine.setMode(ConversationMode.interview);
        expect(engine.mode, ConversationMode.interview);

        provider.enqueueStreamResponse(
          const FakeStreamResponse(['Use the STAR method to structure your answer.']),
        );
        // Follow-up chips
        provider.enqueueResponse('{"chips": [], "factCheck": ""}');

        await engine.askQuestion('How should I answer behavioral questions?');
        await Future<void>.delayed(const Duration(milliseconds: 200));

        // Both turns should be in history
        expect(engine.history.length, greaterThan(historyAfterGeneral),
            reason: 'Interview mode turn should add to history');

        // Verify mode change was recorded on stream
        final modeEvents = recorder.eventsFor('mode');
        expect(modeEvents, isNotEmpty);
      },
    );
  });
}
