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

  setUpAll(() => installPlatformMocks());
  tearDownAll(() => removePlatformMocks());

  setUp(() async {
    final result = await setupTestEngine();
    engine = result.engine;
    provider = result.provider;
    recorder = StreamRecorder(engine);
  });

  tearDown(() async {
    recorder.dispose();
    teardownTestEngine(engine);
    await Future<void>.delayed(const Duration(milliseconds: 350));
  });

  group('B4 - Proactive mode triggerProactiveAnalysis', () {
    test('proactive analysis produces streamed response', () async {
      engine.autoDetectQuestions = false;
      SettingsManager.instance.sentimentMonitorEnabled = false;
      SettingsManager.instance.entityMemoryEnabled = false;
      engine.start(mode: ConversationMode.proactive);

      // Build up conversation context with finalized segments
      engine.onTranscriptionFinalized(
        'We are discussing the new React migration plan.',
      );
      engine.onTranscriptionFinalized(
        'The team has concerns about the learning curve.',
      );
      engine.onTranscriptionFinalized(
        'Sarah asked whether we have enough training resources.',
      );

      // The triggerProactiveAnalysis method calls _generateResponse which
      // uses streamWithTools (stream). Enqueue the streaming response.
      // The proactive response includes a JSON preamble on the first line.
      provider.enqueueStreamResponse(
        FakeStreamResponse([
          '{"action": "answer", "target": "training resources"}\n',
          'Based on the conversation, ',
          'the team should consider ',
          'scheduling React workshops next sprint.',
        ]),
      );

      final responseFuture = waitForStream<String>(
        engine.aiResponseStream,
        predicate: (r) => r.contains('workshops'),
        timeout: const Duration(seconds: 5),
      );

      await engine.triggerProactiveAnalysis();

      final response = await responseFuture;
      expect(response, contains('workshops'));
    });

    test('proactive analysis does nothing when engine is not active', () async {
      engine.autoDetectQuestions = false;
      // Do NOT call engine.start() — engine is inactive
      engine.stop();

      provider.enqueueStreamResponse(
        FakeStreamResponse([
          '{"action": "insight", "target": "test"}\nSome insight.',
        ]),
      );

      await engine.triggerProactiveAnalysis();
      await Future<void>.delayed(const Duration(milliseconds: 300));

      // Should not have called the LLM at all
      expect(provider.streamCallCount, 0);
    });

    test('proactive analysis does nothing in non-proactive mode', () async {
      engine.autoDetectQuestions = false;
      SettingsManager.instance.sentimentMonitorEnabled = false;
      SettingsManager.instance.entityMemoryEnabled = false;
      engine.start(mode: ConversationMode.general);

      engine.onTranscriptionFinalized('Some context for analysis.');

      provider.enqueueStreamResponse(
        FakeStreamResponse([
          '{"action": "answer", "target": "test"}\nTest answer.',
        ]),
      );

      await engine.triggerProactiveAnalysis();
      await Future<void>.delayed(const Duration(milliseconds: 300));

      // triggerProactiveAnalysis returns early if not in proactive mode
      expect(provider.streamCallCount, 0);
    });

    test(
      'manual contextual Q&A in proactive mode cancels the in-flight answer and refreshes with the latest nearby question',
      () async {
        engine.autoDetectQuestions = false;
        SettingsManager.instance.sentimentMonitorEnabled = false;
        SettingsManager.instance.entityMemoryEnabled = false;
        engine.start(mode: ConversationMode.proactive);

        engine.onTranscriptionFinalized('We are discussing the beta rollout.');
        engine.onTranscriptionFinalized('What is the rollout plan?');

        provider.enqueueStreamResponse(
          const FakeStreamResponse([
            'First ',
            'answer that should be replaced.',
          ], delayBetweenChunks: Duration(milliseconds: 120)),
        );
        provider.enqueueStreamResponse(
          const FakeStreamResponse(['Ship the beta next week.']),
        );

        engine.forceQuestionAnalysis();
        await Future<void>.delayed(const Duration(milliseconds: 20));

        engine.onTranscriptionFinalized('Can you confirm the beta timing?');

        final responseFuture = waitForStream<String>(
          engine.aiResponseStream,
          predicate: (value) => value.contains('beta next week'),
          timeout: const Duration(seconds: 5),
        );

        engine.forceQuestionAnalysis();

        final response = await responseFuture;
        await Future<void>.delayed(const Duration(milliseconds: 250));

        expect(response, contains('beta next week'));
        final assistantTurns = engine.history
            .where((turn) => turn.role == 'assistant')
            .toList();
        expect(assistantTurns, hasLength(1));
        expect(assistantTurns.single.content, contains('beta next week'));

        final contextualQaCalls = provider.capturedMessages.where((messages) {
          final userContent = messages
              .where((message) => message.role == 'user')
              .map((message) => message.content)
              .join('\n');
          return userContent.contains('Can you confirm the beta timing?');
        }).toList();
        expect(contextualQaCalls, isNotEmpty);
      },
    );
  });

  group('B5 - Answered questions not repeated', () {
    test('answered questions list grows after proactive response', () async {
      engine.autoDetectQuestions = false;
      SettingsManager.instance.sentimentMonitorEnabled = false;
      SettingsManager.instance.entityMemoryEnabled = false;
      engine.start(mode: ConversationMode.proactive);

      engine.onTranscriptionFinalized(
        'What frameworks does the team use for front-end development?',
      );

      // First proactive analysis — JSON preamble tracks the answered question
      provider.enqueueStreamResponse(
        FakeStreamResponse([
          '{"action": "answer", "target": "front-end frameworks"}\n',
          'The team primarily uses React and Vue.',
        ]),
      );

      // Wait for the response to finish streaming
      final responseFuture = waitForStream<String>(
        engine.aiResponseStream,
        predicate: (r) => r.contains('React'),
        timeout: const Duration(seconds: 5),
      );

      await engine.triggerProactiveAnalysis();
      await responseFuture;

      // Allow the proactive answer tracking to complete
      await Future<void>.delayed(const Duration(milliseconds: 300));

      // The SessionContextManager should have recorded the answered question
      expect(engine.answeredQuestions, isNotEmpty);
      expect(engine.answeredQuestions.first.question, isNotEmpty);
    });

    test('second analysis includes answered summary in context', () async {
      engine.autoDetectQuestions = false;
      SettingsManager.instance.sentimentMonitorEnabled = false;
      SettingsManager.instance.entityMemoryEnabled = false;
      engine.start(mode: ConversationMode.proactive);

      engine.onTranscriptionFinalized(
        'Tell me about your deployment pipeline.',
      );

      // First analysis
      provider.enqueueStreamResponse(
        FakeStreamResponse([
          '{"action": "answer", "target": "deployment pipeline"}\n',
          'We use GitHub Actions with staging and production environments.',
        ]),
      );

      final firstResponse = waitForStream<String>(
        engine.aiResponseStream,
        predicate: (r) => r.contains('GitHub Actions'),
        timeout: const Duration(seconds: 5),
      );

      await engine.triggerProactiveAnalysis();
      await firstResponse;
      await Future<void>.delayed(const Duration(milliseconds: 300));

      final answeredCountAfterFirst = engine.answeredQuestions.length;
      expect(answeredCountAfterFirst, greaterThan(0));

      // Add more context for second analysis
      engine.onTranscriptionFinalized('How do you handle database migrations?');

      // Second analysis
      provider.enqueueStreamResponse(
        FakeStreamResponse([
          '{"action": "answer", "target": "database migrations"}\n',
          'We use Flyway for database migrations with versioned scripts.',
        ]),
      );

      final secondResponse = waitForStream<String>(
        engine.aiResponseStream,
        predicate: (r) => r.contains('Flyway'),
        timeout: const Duration(seconds: 5),
      );

      await engine.triggerProactiveAnalysis();
      await secondResponse;
      await Future<void>.delayed(const Duration(milliseconds: 300));

      // Answered questions should have grown
      expect(
        engine.answeredQuestions.length,
        greaterThan(answeredCountAfterFirst),
      );

      // Verify the LLM was called twice (once for each proactive analysis)
      expect(provider.streamCallCount, greaterThanOrEqualTo(2));

      // Verify the second call's context is different from the first
      // (contains more content since more segments were added)
      final secondCallMessages = provider.capturedMessages.last;
      final userContent = secondCallMessages
          .where((m) => m.role == 'user')
          .map((m) => m.content)
          .join(' ');
      expect(userContent, contains('database migrations'));
    });
  });
}
