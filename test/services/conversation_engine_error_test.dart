import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_helix/services/conversation_engine.dart';
import 'package:flutter_helix/services/llm/llm_provider.dart';
import 'package:flutter_helix/services/llm/llm_service.dart';
import 'package:flutter_helix/services/provider_error_state.dart';
import 'package:flutter_helix/services/settings_manager.dart';

import '../helpers/test_helpers.dart';
import '../helpers/stream_recorder.dart';

// ---------------------------------------------------------------------------
// Custom provider that throws mid-stream for E2
// ---------------------------------------------------------------------------

class ThrowingStreamProvider extends FakeJsonProvider {
  ThrowingStreamProvider({super.responses, super.streamResponses});

  /// When true, the next streamWithTools call will yield one chunk then throw.
  bool throwAfterFirstChunk = false;

  @override
  Stream<LlmResponseEvent> streamWithTools({
    required String systemPrompt,
    required List<ChatMessage> messages,
    List<ToolDefinition>? tools,
    String? model,
    double temperature = 0.7,
  }) async* {
    if (throwAfterFirstChunk) {
      yield TextDelta('partial answer ');
      throw Exception('Simulated network failure mid-stream');
    }
    await for (final chunk in super.streamWithTools(
      systemPrompt: systemPrompt,
      messages: messages,
      tools: tools,
      model: model,
      temperature: temperature,
    )) {
      yield chunk;
    }
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ConversationEngine engine;
  late StreamRecorder recorder;

  group('ConversationEngine error handling', () {
    // E2 [P0]: Network failure mid-stream -> error state -> idle
    test(
      'E2: network failure mid-stream emits provider error and returns to idle',
      () async {
        installPlatformMocks();
        await initTestSettings(
          overrides: {'language': 'en', 'transcriptionBackend': 'appleCloud'},
        );
        ConversationEngine.resetTestHooks();
        SettingsManager.instance.assistantProfileId = 'professional';

        final throwingProvider = ThrowingStreamProvider();
        throwingProvider.throwAfterFirstChunk = true;

        final llm = LlmService.instance;
        llm.registerProvider(throwingProvider);
        llm.setActiveProvider('fake');
        ConversationEngine.setLlmServiceGetter(() => llm);

        engine = ConversationEngine.instance;
        engine.clearHistory();
        engine.stop();
        recorder = StreamRecorder(engine);

        // Listen for provider errors
        final errorFuture = engine.providerErrorStream.firstWhere(
          (e) => e != null,
        );

        engine.start();
        await engine.askQuestion('What is the meaning of life?');
        await Future<void>.delayed(const Duration(milliseconds: 300));

        // Verify: providerErrorStream emits non-null error
        final error = await errorFuture.timeout(
          const Duration(seconds: 2),
          onTimeout: () => null,
        );
        expect(
          error,
          isNotNull,
          reason: 'Should emit a provider error on stream failure',
        );

        // Verify: statusStream eventually returns to idle (engine was started, so listening)
        final terminalStatuses = recorder.statuses
            .where((s) => s == EngineStatus.idle || s == EngineStatus.listening)
            .toList();
        expect(
          terminalStatuses,
          isNotEmpty,
          reason: 'Status should return to idle or listening after error',
        );

        // Verify: history should NOT contain incomplete "partial answer" as assistant turn
        final assistantTurns = engine.history
            .where((t) => t.role == 'assistant')
            .toList();
        // The error handler emits the error message via aiResponseController
        // but should NOT persist a half-streamed answer as a normal assistant turn.
        // If an assistant turn exists, it should be the error message, not the partial.
        for (final turn in assistantTurns) {
          expect(
            turn.content,
            isNot(equals('partial answer ')),
            reason: 'Should not persist incomplete streamed answer',
          );
        }

        recorder.dispose();
        teardownTestEngine(engine);
        removePlatformMocks();
      },
    );

    // E3 [P1]: LLM returns [Error] prefix -> ProviderErrorState
    test('E3: LLM returning [Error] prefix triggers provider error', () async {
      final setup = await setupTestEngine(
        streamResponses: [
          const FakeStreamResponse(['[Error] HTTP 429 Too Many Requests']),
        ],
        settingsOverrides: {
          'language': 'en',
          'transcriptionBackend': 'appleCloud',
        },
      );
      engine = setup.engine;
      recorder = StreamRecorder(engine);

      final errorFuture = engine.providerErrorStream.firstWhere(
        (e) => e != null,
      );

      engine.start();
      await engine.askQuestion('Tell me about quantum computing');
      await Future<void>.delayed(const Duration(milliseconds: 300));

      final error = await errorFuture.timeout(
        const Duration(seconds: 2),
        onTimeout: () => null,
      );
      expect(
        error,
        isNotNull,
        reason: 'Should emit provider error for [Error] prefixed response',
      );
      expect(
        error!.kind,
        ProviderErrorKind.rateLimited,
        reason: '[Error] with 429 should map to rateLimited',
      );

      // Status should return to listening (engine is active) or idle
      final lastStatus = recorder.statuses.last;
      expect(
        lastStatus == EngineStatus.listening || lastStatus == EngineStatus.idle,
        isTrue,
        reason: 'Status should recover after error',
      );

      recorder.dispose();
      teardownTestEngine(engine);
    });

    // E6 [P2]: Empty transcript -> no segment added
    test(
      'E6: empty transcript finalization does not crash or add empty segment',
      () async {
        final setup = await setupTestEngine(
          settingsOverrides: {
            'language': 'en',
            'transcriptionBackend': 'appleCloud',
          },
        );
        engine = setup.engine;
        recorder = StreamRecorder(engine);

        engine.start();

        // Record snapshot count before the empty finalization
        await Future<void>.delayed(const Duration(milliseconds: 50));
        // Finalize empty text
        engine.onTranscriptionFinalized('');
        await Future<void>.delayed(const Duration(milliseconds: 100));

        // Engine should not crash
        expect(engine.isActive, isTrue);

        // The current transcript snapshot should have no finalized segments
        // (or same count as before — no new segment with empty text)
        final snapshot = engine.currentTranscriptSnapshot;
        final emptySegments = snapshot.finalizedSegments
            .where((s) => s.isEmpty)
            .toList();
        expect(
          emptySegments,
          isEmpty,
          reason: 'Should not add empty finalized segments',
        );

        // History should remain unchanged
        expect(
          engine.history,
          isEmpty,
          reason: 'Empty transcript should not trigger any history changes',
        );

        recorder.dispose();
        teardownTestEngine(engine);
      },
    );

    // E7 [P2]: Concurrent askQuestion -> second cancels first
    test('E7: concurrent askQuestion calls — second supersedes first', () async {
      final setup = await setupTestEngine(
        streamResponses: [
          // First response: slow stream
          const FakeStreamResponse([
            'Answer to Q1 part 1. ',
            'Answer to Q1 part 2.',
          ], delayBetweenChunks: Duration(milliseconds: 200)),
          // Second response: fast stream
          const FakeStreamResponse(['Answer to Q2.']),
        ],
        // Follow-up chips for each
        responses: [
          '{"followUpChips": [], "factCheck": ""}',
          '{"followUpChips": [], "factCheck": ""}',
        ],
        settingsOverrides: {
          'language': 'en',
          'transcriptionBackend': 'appleCloud',
        },
      );
      engine = setup.engine;
      recorder = StreamRecorder(engine);

      engine.start();

      // Fire first question without awaiting
      unawaited(engine.askQuestion('Question 1'));

      // Small delay so the first starts streaming
      await Future<void>.delayed(const Duration(milliseconds: 50));

      // Fire second question — this should cancel the first via _beginResponseCycle
      await engine.askQuestion('Question 2');
      await Future<void>.delayed(const Duration(milliseconds: 300));

      // The second question's answer should appear in history.
      // The first question may or may not have completed depending on timing;
      // what matters is the engine doesn't crash and the second answer is present.
      final assistantTurns = engine.history
          .where((t) => t.role == 'assistant')
          .toList();
      expect(
        assistantTurns,
        isNotEmpty,
        reason: 'At least one assistant response should be in history',
      );

      // The last assistant response should be from Q2
      final lastAssistant = assistantTurns.last;
      expect(
        lastAssistant.content,
        contains('Q2'),
        reason: 'The second question answer should be the final one',
      );

      recorder.dispose();
      teardownTestEngine(engine);
    });
  });
}
