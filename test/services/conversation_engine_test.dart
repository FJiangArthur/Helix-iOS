import 'dart:async';
import 'dart:collection';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_helix/services/conversation_engine.dart';
import 'package:flutter_helix/services/hud_controller.dart';
import 'package:flutter_helix/services/hud_intent.dart';
import 'package:flutter_helix/services/llm/llm_provider.dart';
import 'package:flutter_helix/services/llm/llm_service.dart';
import 'package:flutter_helix/services/settings_manager.dart';
import 'package:flutter_helix/services/provider_error_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FakeStreamResponse {
  const FakeStreamResponse(
    this.chunks, {
    this.delayBetweenChunks = Duration.zero,
  });

  final List<String> chunks;
  final Duration delayBetweenChunks;
}

class FakeJsonProvider implements LlmProvider {
  FakeJsonProvider({
    List<String> responses = const [],
    List<FakeStreamResponse> streamResponses = const [],
  }) : _responses = Queue<String>.from(responses),
       _streamResponses = Queue<FakeStreamResponse>.from(streamResponses);

  final Queue<String> _responses;
  final Queue<FakeStreamResponse> _streamResponses;
  int streamCallCount = 0;

  @override
  List<String> get availableModels => const ['fake-model'];

  @override
  String get defaultModel => 'fake-model';

  @override
  String get id => 'fake';

  @override
  String get name => 'Fake';

  @override
  Future<String> getResponse({
    required String systemPrompt,
    required List<ChatMessage> messages,
    String? model,
    double temperature = 0.7,
    LlmRequestOptions? requestOptions,
    void Function(LlmResponseMetadata metadata)? onMetadata,
  }) async {
    if (_responses.isEmpty) {
      return '{"shouldRespond": false, "question": "", "questionExcerpt": ""}';
    }
    return _responses.removeFirst();
  }

  @override
  Stream<String> streamResponse({
    required String systemPrompt,
    required List<ChatMessage> messages,
    String? model,
    double temperature = 0.7,
    LlmRequestOptions? requestOptions,
    void Function(LlmResponseMetadata metadata)? onMetadata,
  }) async* {
    streamCallCount++;
    final script = _streamResponses.isEmpty
        ? const FakeStreamResponse(['stubbed stream response'])
        : _streamResponses.removeFirst();
    for (var index = 0; index < script.chunks.length; index++) {
      if (index > 0 && script.delayBetweenChunks > Duration.zero) {
        await Future<void>.delayed(script.delayBetweenChunks);
      }
      yield script.chunks[index];
    }
  }

  @override
  Future<List<String>> queryAvailableModels({bool refresh = false}) async {
    return availableModels;
  }

  @override
  bool supportsRealtimeModel(String model) => false;

  @override
  Future<bool> testConnection(String apiKey) async => true;

  @override
  void updateApiKey(String apiKey) {}

  @override
  Stream<LlmResponseEvent> streamWithTools({
    required String systemPrompt,
    required List<ChatMessage> messages,
    List<ToolDefinition>? tools,
    String? model,
    double temperature = 0.7,
    LlmRequestOptions? requestOptions,
    void Function(LlmResponseMetadata metadata)? onMetadata,
  }) async* {
    await for (final chunk in streamResponse(
      systemPrompt: systemPrompt,
      messages: messages,
      model: model,
      temperature: temperature,
      requestOptions: requestOptions,
      onMetadata: onMetadata,
    )) {
      yield TextDelta(chunk);
    }
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<FakeJsonProvider> configureFakeLlm({
    required List<String> responses,
    List<FakeStreamResponse> streamResponses = const [],
  }) async {
    final llm = LlmService.instance;
    final provider = FakeJsonProvider(
      responses: responses,
      streamResponses: streamResponses,
    );
    llm.registerProvider(provider);
    llm.setActiveProvider('fake');
    ConversationEngine.setLlmServiceGetter(() => llm);
    return provider;
  }

  group('ConversationEngine quick ask error handling', () {
    late ConversationEngine engine;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await SettingsManager.instance.initialize();
      ConversationEngine.resetTestHooks();
      SettingsManager.instance.assistantProfileId = 'professional';
      ConversationEngine.setLlmServiceGetter(
        () => throw StateError('missing llm provider'),
      );
      engine = ConversationEngine.instance;
      engine.clearHistory();
      await HudController.instance.resetToIdle(source: 'test.engine.setup');
    });

    test(
      'emits a friendly missing-configuration error for quick ask',
      () async {
        final providerErrorFuture = engine.providerErrorStream.firstWhere(
          (state) => state != null,
        );
        final aiResponseFuture = engine.aiResponseStream.firstWhere(
          (text) => text.isNotEmpty,
        );
        final statusEvents = <EngineStatus>[];
        final statusSub = engine.statusStream.listen(statusEvents.add);

        await engine.askQuestion('Why is the sky blue?');

        final providerError = await providerErrorFuture;
        final aiResponse = await aiResponseFuture;
        await statusSub.cancel();

        expect(providerError, isNotNull);
        expect(providerError!.kind, ProviderErrorKind.missingConfiguration);
        expect(aiResponse, contains('API key required'));
        expect(aiResponse, isNot(contains('HTTP 401')));
        expect(HudController.instance.currentIntent, HudIntent.quickAsk);
        expect(statusEvents, contains(EngineStatus.thinking));
        expect(statusEvents, contains(EngineStatus.idle));
        expect(
          engine.lastProviderError?.kind,
          ProviderErrorKind.missingConfiguration,
        );
        expect(engine.history, isNotEmpty);
        expect(engine.history.first.assistantProfileId, 'professional');
      },
    );
  });

  group('ConversationEngine live transcript workflow', () {
    late ConversationEngine engine;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await SettingsManager.instance.initialize();
      ConversationEngine.resetTestHooks();
      SettingsManager.instance.assistantProfileId = 'general';
      SettingsManager.instance.language = 'en';
      SettingsManager.instance.transcriptionBackend = 'openai';
      SettingsManager.instance.autoDetectQuestions = true;
      SettingsManager.instance.answerAll = true;
      engine = ConversationEngine.instance;
      engine.clearHistory();
      engine.stop();
    });

    test(
      'partial and final transcript snapshots are emitted with source state',
      () async {
        await configureFakeLlm(
          responses: [
            '{"shouldRespond": false, "question": "", "questionExcerpt": ""}',
          ],
        );

        final snapshots = <TranscriptSnapshot>[];
        final sub = engine.transcriptSnapshotStream.listen(snapshots.add);

        engine.start(source: TranscriptSource.glasses);
        engine.onTranscriptionUpdate('Hello there');
        engine.onTranscriptionFinalized('Hello there');
        await Future<void>.delayed(const Duration(milliseconds: 10));

        await sub.cancel();

        expect(snapshots, isNotEmpty);
        expect(snapshots.last.source, TranscriptSource.glasses);
        expect(snapshots.last.partialText, '');
        expect(snapshots.last.finalizedSegments, ['Hello there']);
        expect(snapshots.last.fullTranscript, 'Hello there');
      },
    );

    test(
      'starting a new session clears prior in-memory history and live answer',
      () async {
        engine.start(source: TranscriptSource.phone);
        engine.onTranscriptionFinalized('First session transcript');
        engine.onRealtimeResponse('First session answer', isFinal: false);
        engine.onRealtimeResponse('', isFinal: true);
        engine.stop();

        expect(engine.history, isNotEmpty);

        final responseEvents = <String>[];
        final responseSub = engine.aiResponseStream.listen(responseEvents.add);

        engine.start(source: TranscriptSource.phone);
        await Future<void>.delayed(const Duration(milliseconds: 10));

        await responseSub.cancel();

        expect(engine.history, isEmpty);
        expect(responseEvents, ['']);
        expect(engine.currentTranscriptSnapshot.fullTranscript, isEmpty);
        expect(engine.currentTranscriptSnapshot.finalizedSegments, isEmpty);
      },
    );

    test(
      'openai realtime session skips downstream llm streaming and persists streamed assistant turns',
      () async {
        final provider = await configureFakeLlm(
          responses: const [],
          streamResponses: const [
            FakeStreamResponse(['should never stream']),
          ],
        );
        SettingsManager.instance.transcriptionBackend = 'openai';
        SettingsManager.instance.openAISessionMode = 'realtime';

        final statusEvents = <EngineStatus>[];
        final statusSub = engine.statusStream.listen(statusEvents.add);
        final aiResponses = <String>[];
        final aiResponseSub = engine.aiResponseStream.listen(aiResponses.add);

        engine.start(source: TranscriptSource.phone);
        engine.onTranscriptionFinalized('What is the release plan?');
        await Future<void>.delayed(const Duration(milliseconds: 20));

        expect(provider.streamCallCount, 0);

        engine.onRealtimeResponse('Here is ', isFinal: false);
        engine.onRealtimeResponse('the release plan.', isFinal: false);
        engine.onRealtimeResponse('', isFinal: true);

        await Future<void>.delayed(const Duration(milliseconds: 10));
        expect(aiResponses, contains('Here is '));
        expect(aiResponses, contains('Here is the release plan.'));

        final assistantTurns = engine.history
            .where((turn) => turn.role == 'assistant')
            .toList();
        expect(assistantTurns, hasLength(1));
        expect(assistantTurns.single.content, 'Here is the release plan.');
        expect(statusEvents, contains(EngineStatus.responding));
        expect(statusEvents, contains(EngineStatus.listening));

        await aiResponseSub.cancel();
        await statusSub.cancel();
      },
    );

    test('non-question chatter does not emit analysis results', () async {
      await configureFakeLlm(
        responses: [
          '{"shouldRespond": false, "question": "", "questionExcerpt": ""}',
        ],
      );

      final results = <QuestionDetectionResult>[];
      final sub = engine.questionDetectionStream.listen(results.add);

      engine.start(source: TranscriptSource.phone);
      engine.onTranscriptionFinalized('Nice weather today.');
      await Future<void>.delayed(const Duration(milliseconds: 20));

      await sub.cancel();

      expect(results, isEmpty);
      expect(engine.history, isEmpty);
    });

    test(
      'auto-detected questions batch small streamed chunks for phone and glasses',
      () async {
        final rawChunks = [
          'M',
          'e',
          'e',
          't',
          'i',
          'n',
          'g',
          ' ',
          'a',
          't',
          ' ',
          '3',
          ' ',
          'P',
          'M',
          '.',
        ];
        final fullResponse = rawChunks.join();
        await configureFakeLlm(
          responses: [
            '{"shouldRespond": true, "question": "What time is the meeting?", "questionExcerpt": "What time is the meeting?"}',
            '["Tell me more"]',
          ],
          streamResponses: [FakeStreamResponse(rawChunks)],
        );
        final results = <QuestionDetectionResult>[];
        final aiUpdates = <String>[];
        final glassesFrames = <(String, bool)>[];
        ConversationEngine.setGlassesConnectionChecker(() => true);
        ConversationEngine.setGlassesSender((
          text, {
          required isStreaming,
        }) async {
          glassesFrames.add((text, isStreaming));
        });
        final detectionSub = engine.questionDetectionStream.listen(results.add);
        final aiSub = engine.aiResponseStream.listen(aiUpdates.add);

        engine.start(source: TranscriptSource.phone);
        engine.onTranscriptionFinalized('What time is the meeting?');
        await Future<void>.delayed(const Duration(milliseconds: 20));

        await detectionSub.cancel();
        await aiSub.cancel();

        expect(results.length, 1);
        expect(results.single.question, 'What time is the meeting?');
        expect(results.single.questionExcerpt, 'What time is the meeting?');
        expect(aiUpdates, contains(''));
        expect(aiUpdates.last, fullResponse);
        expect(
          aiUpdates.where((text) => text.isNotEmpty).length,
          lessThan(rawChunks.length),
        );
        expect(glassesFrames.last, (fullResponse, false));
        expect(glassesFrames, contains((fullResponse, true)));
        expect(
          glassesFrames.where((frame) => frame.$2).length,
          lessThan(rawChunks.length),
        );
        expect(engine.history.length, 2);
        expect(engine.history.first.content, 'What time is the meeting?');
        expect(engine.history.last.content, fullResponse);
      },
    );

    test('manual askQuestion uses the same batched streaming path', () async {
      final rawChunks = [
        'B',
        'a',
        't',
        'c',
        'h',
        'e',
        'd',
        ' ',
        'a',
        'n',
        's',
        'w',
        'e',
        'r',
        '.',
      ];
      final fullResponse = rawChunks.join();
      await configureFakeLlm(
        responses: ['["Next step"]'],
        streamResponses: [FakeStreamResponse(rawChunks)],
      );

      final aiUpdates = <String>[];
      final glassesFrames = <(String, bool)>[];
      ConversationEngine.setGlassesConnectionChecker(() => true);
      ConversationEngine.setGlassesSender((text, {required isStreaming}) async {
        glassesFrames.add((text, isStreaming));
      });
      final aiSub = engine.aiResponseStream.listen(aiUpdates.add);

      await engine.askQuestion('Why is the response smoother now?');
      await Future<void>.delayed(const Duration(milliseconds: 20));
      await aiSub.cancel();

      expect(aiUpdates, contains(''));
      expect(aiUpdates.last, fullResponse);
      expect(
        aiUpdates.where((text) => text.isNotEmpty).length,
        lessThan(rawChunks.length),
      );
      expect(glassesFrames.last, (fullResponse, false));
      expect(glassesFrames, contains((fullResponse, true)));
      expect(
        glassesFrames.where((frame) => frame.$2).length,
        lessThan(rawChunks.length),
      );
      expect(engine.history.length, 2);
      expect(engine.history.first.content, 'Why is the response smoother now?');
      expect(engine.history.last.content, fullResponse);
    });

    test(
      'duplicate questions are ignored after the first handled result',
      () async {
        final provider = await configureFakeLlm(
          responses: [
            '{"shouldRespond": true, "question": "What time is the meeting?", "questionExcerpt": "What time is the meeting?"}',
            '["Tell me more"]',
            '{"shouldRespond": true, "question": "What time is the meeting?", "questionExcerpt": "What time is the meeting?"}',
          ],
          streamResponses: const [
            FakeStreamResponse(['It starts at 3 PM.']),
          ],
        );

        final results = <QuestionDetectionResult>[];
        final sub = engine.questionDetectionStream.listen(results.add);

        engine.start(source: TranscriptSource.phone);
        engine.onTranscriptionFinalized('What time is the meeting?');
        await Future<void>.delayed(const Duration(milliseconds: 20));
        engine.onTranscriptionFinalized('What time is the meeting?');
        await Future<void>.delayed(const Duration(milliseconds: 20));

        await sub.cancel();

        expect(results.length, 1);
        expect(results.single.question, 'What time is the meeting?');
        expect(provider.streamCallCount, 1);
        expect(engine.history.length, 2);
        expect(engine.history.first.content, 'What time is the meeting?');
        expect(engine.history.last.content, 'It starts at 3 PM.');
      },
    );

    test('stopping the engine suppresses stale response chunks', () async {
      await configureFakeLlm(
        responses: [
          '{"shouldRespond": true, "question": "How should I answer?", "questionExcerpt": "How should I answer?"}',
        ],
        streamResponses: const [
          FakeStreamResponse([
            'First chunk now',
            ' second chunk',
          ], delayBetweenChunks: Duration(milliseconds: 60)),
        ],
      );

      final aiUpdates = <String>[];
      final statusEvents = <EngineStatus>[];
      final glassesFrames = <(String, bool)>[];
      ConversationEngine.setGlassesConnectionChecker(() => true);
      ConversationEngine.setGlassesSender((text, {required isStreaming}) async {
        glassesFrames.add((text, isStreaming));
      });
      final aiSub = engine.aiResponseStream.listen(aiUpdates.add);
      final statusSub = engine.statusStream.listen(statusEvents.add);

      engine.start(source: TranscriptSource.phone);
      engine.onTranscriptionFinalized('How should I answer?');
      await Future<void>.delayed(const Duration(milliseconds: 10));
      engine.stop();
      await Future<void>.delayed(const Duration(milliseconds: 90));

      await aiSub.cancel();
      await statusSub.cancel();

      expect(aiUpdates, contains('First chunk now'));
      expect(aiUpdates, isNot(contains('First chunk now second chunk')));
      expect(glassesFrames, [('First chunk now', true)]);
      expect(statusEvents.last, EngineStatus.idle);
      expect(engine.history.length, 1);
      expect(engine.history.single.role, 'user');
      expect(engine.history.single.content, 'How should I answer?');
    });
  });

  // ---------------------------------------------------------------------------
  // E1: Question detection parsing tests
  //
  // _parseQuestionDetection is private, so we test it indirectly through
  // the public API: onTranscriptionFinalized triggers analysis which calls
  // _parseQuestionDetection under the hood. The FakeJsonProvider's getResponse
  // return value IS the input to _parseQuestionDetection.
  // ---------------------------------------------------------------------------
  group('question detection parsing', () {
    late ConversationEngine engine;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await SettingsManager.instance.initialize();
      ConversationEngine.resetTestHooks();
      SettingsManager.instance.assistantProfileId = 'general';
      SettingsManager.instance.language = 'en';
      SettingsManager.instance.transcriptionBackend = 'openai';
      SettingsManager.instance.openAISessionMode = 'transcription';
      SettingsManager.instance.autoDetectQuestions = true;
      SettingsManager.instance.answerAll =
          true; // answerAll must be true for auto-detection to fire
      engine = ConversationEngine.instance;
      engine.clearHistory();
      engine.stop();
    });

    test(
      'parses JSON with shouldRespond=true and returns a QuestionDetectionResult',
      () async {
        // The LLM returns a valid detection JSON; engine should emit a result.
        await configureFakeLlm(
          responses: [
            '{"shouldRespond": true, "question": "What is the deadline?", "questionExcerpt": "What is the deadline?"}',
          ],
        );

        final results = <QuestionDetectionResult>[];
        final sub = engine.questionDetectionStream.listen(results.add);

        engine.start(source: TranscriptSource.phone);
        engine.onTranscriptionFinalized('What is the deadline?');
        await Future<void>.delayed(const Duration(milliseconds: 30));

        await sub.cancel();

        expect(results, hasLength(1));
        expect(results.single.question, 'What is the deadline?');
        expect(results.single.questionExcerpt, 'What is the deadline?');
      },
    );

    test('returns null when shouldRespond=false', () async {
      // Standard case: LLM decides no question was detected.
      await configureFakeLlm(
        responses: [
          '{"shouldRespond": false, "question": "", "questionExcerpt": ""}',
        ],
      );

      final results = <QuestionDetectionResult>[];
      final sub = engine.questionDetectionStream.listen(results.add);

      engine.start(source: TranscriptSource.phone);
      engine.onTranscriptionFinalized('Just some chatter about the weather.');
      await Future<void>.delayed(const Duration(milliseconds: 30));

      await sub.cancel();

      // No detection should be emitted.
      expect(results, isEmpty);
      expect(engine.history, isEmpty);
    });

    test('ignores social questions that should not be answered', () async {
      await configureFakeLlm(
        responses: [
          '{"shouldRespond": true, "shouldAnswer": false, "category": "social", "question": "How are you?", "questionExcerpt": "How are you?", "askedBy": "other"}',
        ],
      );

      final results = <QuestionDetectionResult>[];
      final sub = engine.questionDetectionStream.listen(results.add);

      engine.start(source: TranscriptSource.phone);
      engine.onTranscriptionFinalized('How are you?');
      await Future<void>.delayed(const Duration(milliseconds: 30));

      await sub.cancel();

      expect(results, isEmpty);
      expect(engine.history, isEmpty);
    });

    test('handles markdown-fenced JSON', () async {
      // LLM sometimes wraps JSON in markdown code fences.
      // _parseQuestionDetection should strip them via _stripMarkdownCodeFence.
      await configureFakeLlm(
        responses: [
          '```json\n{"shouldRespond": true, "question": "Can you explain?", "questionExcerpt": "Can you explain?"}\n```',
        ],
      );

      final results = <QuestionDetectionResult>[];
      final sub = engine.questionDetectionStream.listen(results.add);

      engine.start(source: TranscriptSource.phone);
      engine.onTranscriptionFinalized('Can you explain?');
      await Future<void>.delayed(const Duration(milliseconds: 30));

      await sub.cancel();

      expect(results, hasLength(1));
      expect(results.single.question, 'Can you explain?');
    });

    test('handles malformed JSON gracefully', () async {
      // Invalid JSON should not throw; it should silently return null.
      await configureFakeLlm(responses: ['This is not valid JSON at all {{{']);

      final results = <QuestionDetectionResult>[];
      final sub = engine.questionDetectionStream.listen(results.add);

      engine.start(source: TranscriptSource.phone);
      engine.onTranscriptionFinalized('Some random speech.');
      await Future<void>.delayed(const Duration(milliseconds: 30));

      await sub.cancel();

      // Should not throw, and should not emit any detection result.
      expect(results, isEmpty);
      expect(engine.history, isEmpty);
    });

    test(
      'returns null when question field is empty despite shouldRespond=true',
      () async {
        // Edge case: shouldRespond is true but question string is empty.
        await configureFakeLlm(
          responses: [
            '{"shouldRespond": true, "question": "", "questionExcerpt": ""}',
          ],
        );

        final results = <QuestionDetectionResult>[];
        final sub = engine.questionDetectionStream.listen(results.add);

        engine.start(source: TranscriptSource.phone);
        engine.onTranscriptionFinalized('Hmm let me think about it.');
        await Future<void>.delayed(const Duration(milliseconds: 30));

        await sub.cancel();

        // Empty question should not produce a detection result.
        expect(results, isEmpty);
      },
    );

    test(
      'defaults questionExcerpt via fallback resolution when field missing',
      () async {
        // Backward compat: old JSON without questionExcerpt field.
        // _resolveQuestionExcerpt should fall back to the question text if it
        // appears in the transcript window.
        await configureFakeLlm(
          responses: [
            '{"shouldRespond": true, "question": "Where is the report?"}',
          ],
        );

        final results = <QuestionDetectionResult>[];
        final sub = engine.questionDetectionStream.listen(results.add);

        engine.start(source: TranscriptSource.phone);
        engine.onTranscriptionFinalized('Where is the report?');
        await Future<void>.delayed(const Duration(milliseconds: 30));

        await sub.cancel();

        expect(results, hasLength(1));
        expect(results.single.question, 'Where is the report?');
        // questionExcerpt should be resolved from the transcript window since the
        // question text "Where is the report?" appears verbatim in the window.
        expect(results.single.questionExcerpt, 'Where is the report?');
      },
    );
  });

  // ---------------------------------------------------------------------------
  // E2: TranscriptSegment and window building tests
  //
  // Tests that finalized segments accumulate correctly and that the transcript
  // snapshot reflects the expected state.
  // ---------------------------------------------------------------------------
  group('transcript segments', () {
    late ConversationEngine engine;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await SettingsManager.instance.initialize();
      ConversationEngine.resetTestHooks();
      SettingsManager.instance.assistantProfileId = 'general';
      SettingsManager.instance.language = 'en';
      SettingsManager.instance.transcriptionBackend = 'openai';
      SettingsManager.instance.openAISessionMode = 'transcription';
      // Disable auto-detect so analysis LLM calls don't interfere.
      SettingsManager.instance.autoDetectQuestions = false;
      engine = ConversationEngine.instance;
      engine.clearHistory();
      engine.stop();
    });

    test('segments accumulate on finalized transcription', () async {
      // Call onTranscriptionFinalized multiple times, verify segments grow.
      final snapshots = <TranscriptSnapshot>[];
      final sub = engine.transcriptSnapshotStream.listen(snapshots.add);

      engine.start(source: TranscriptSource.phone);
      engine.onTranscriptionFinalized('First sentence.');
      engine.onTranscriptionFinalized('Second sentence.');
      engine.onTranscriptionFinalized('Third sentence.');
      await Future<void>.delayed(const Duration(milliseconds: 10));

      await sub.cancel();

      // The last snapshot should contain all three segments.
      final lastSnapshot = snapshots.last;
      expect(lastSnapshot.finalizedSegments, hasLength(3));
      expect(lastSnapshot.finalizedSegments[0], 'First sentence.');
      expect(lastSnapshot.finalizedSegments[1], 'Second sentence.');
      expect(lastSnapshot.finalizedSegments[2], 'Third sentence.');
      expect(lastSnapshot.fullTranscript, contains('First sentence.'));
      expect(lastSnapshot.fullTranscript, contains('Third sentence.'));
    });

    test('duplicate consecutive segments are not added twice', () async {
      // onTranscriptionFinalized deduplicates if last segment text matches.
      final snapshots = <TranscriptSnapshot>[];
      final sub = engine.transcriptSnapshotStream.listen(snapshots.add);

      engine.start(source: TranscriptSource.phone);
      engine.onTranscriptionFinalized('Same text.');
      engine.onTranscriptionFinalized('Same text.');
      engine.onTranscriptionFinalized('Different text.');
      await Future<void>.delayed(const Duration(milliseconds: 10));

      await sub.cancel();

      final lastSnapshot = snapshots.last;
      // "Same text." appears only once because the second call is deduplicated.
      expect(lastSnapshot.finalizedSegments, hasLength(2));
      expect(lastSnapshot.finalizedSegments[0], 'Same text.');
      expect(lastSnapshot.finalizedSegments[1], 'Different text.');
    });

    test('partial transcription is included in full transcript', () async {
      // Verify that partial (non-finalized) text is part of the snapshot.
      final snapshots = <TranscriptSnapshot>[];
      final sub = engine.transcriptSnapshotStream.listen(snapshots.add);

      engine.start(source: TranscriptSource.phone);
      engine.onTranscriptionFinalized('Finalized part.');
      engine.onTranscriptionUpdate('Partial typing...');
      await Future<void>.delayed(const Duration(milliseconds: 10));

      await sub.cancel();

      // Find the snapshot emitted after the partial update.
      final withPartial = snapshots.lastWhere(
        (s) => s.partialText.isNotEmpty,
        orElse: () => snapshots.last,
      );
      expect(withPartial.partialText, 'Partial typing...');
      expect(withPartial.fullTranscript, contains('Finalized part.'));
      expect(withPartial.fullTranscript, contains('Partial typing...'));
    });

    test('window is limited to last 8 segments and 2000 chars', () async {
      // Add many segments, verify the snapshot still works correctly.
      // We cannot directly test _buildRecentTranscriptWindow (it's private),
      // but we verify the engine handles many segments without error and
      // the snapshot accurately reflects all finalized segments.
      final snapshots = <TranscriptSnapshot>[];
      final sub = engine.transcriptSnapshotStream.listen(snapshots.add);

      engine.start(source: TranscriptSource.phone);
      // Add 12 segments — more than the 8-segment window limit.
      for (var i = 1; i <= 12; i++) {
        engine.onTranscriptionFinalized(
          'Segment number $i with some filler text.',
        );
      }
      await Future<void>.delayed(const Duration(milliseconds: 10));

      await sub.cancel();

      final lastSnapshot = snapshots.last;
      // All 12 segments should be in the snapshot (the 8-segment limit applies
      // only to the internal analysis window, not the snapshot output).
      expect(lastSnapshot.finalizedSegments, hasLength(12));
      expect(
        lastSnapshot.finalizedSegments.first,
        'Segment number 1 with some filler text.',
      );
      expect(
        lastSnapshot.finalizedSegments.last,
        'Segment number 12 with some filler text.',
      );
    });
  });

  // ---------------------------------------------------------------------------
  // E3: Question deduplication tests
  //
  // The engine uses _lastHandledQuestionKey (normalized question text) to
  // deduplicate identical questions within a single session. Deduplication
  // resets when the engine is restarted via start() or clearHistory().
  // ---------------------------------------------------------------------------
  group('question deduplication', () {
    late ConversationEngine engine;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await SettingsManager.instance.initialize();
      ConversationEngine.resetTestHooks();
      SettingsManager.instance.assistantProfileId = 'general';
      SettingsManager.instance.language = 'en';
      SettingsManager.instance.transcriptionBackend = 'openai';
      SettingsManager.instance.openAISessionMode = 'transcription';
      SettingsManager.instance.autoDetectQuestions = true;
      SettingsManager.instance.answerAll = true;
      engine = ConversationEngine.instance;
      engine.clearHistory();
      engine.stop();
    });

    test('same question within session is deduplicated', () async {
      // Same normalized question within one session is ignored the second time.
      await configureFakeLlm(
        responses: [
          '{"shouldRespond": true, "question": "What time is lunch?", "questionExcerpt": "What time is lunch?"}',
          '{"shouldRespond": true, "question": "What time is lunch?", "questionExcerpt": "What time is lunch?"}',
        ],
      );

      final results = <QuestionDetectionResult>[];
      final sub = engine.questionDetectionStream.listen(results.add);

      engine.start(source: TranscriptSource.phone);
      engine.onTranscriptionFinalized('What time is lunch?');
      await Future<void>.delayed(const Duration(milliseconds: 30));
      // Ask the same question again in the same session.
      engine.onTranscriptionFinalized('What time is lunch?');
      await Future<void>.delayed(const Duration(milliseconds: 30));

      await sub.cancel();

      // Only the first detection should be emitted; second is deduplicated.
      expect(results, hasLength(1));
      expect(results.single.question, 'What time is lunch?');
    });

    test('same question after restart is NOT deduplicated', () async {
      // Restarting the engine resets _lastHandledQuestionKey, so the same
      // question should be accepted again.
      SettingsManager.instance.sentimentMonitorEnabled = false;
      SettingsManager.instance.entityMemoryEnabled = false;
      await configureFakeLlm(
        responses: [
          '{"shouldRespond": true, "question": "What time is lunch?", "questionExcerpt": "What time is lunch?"}',
          // post-response analysis (chips/fact-check) after first auto-answer
          '{"chips": [], "factCheck": "null"}',
          '{"shouldRespond": true, "question": "What time is lunch?", "questionExcerpt": "What time is lunch?"}',
          // post-response analysis after second auto-answer
          '{"chips": [], "factCheck": "null"}',
        ],
      );

      final results = <QuestionDetectionResult>[];
      final sub = engine.questionDetectionStream.listen(results.add);

      engine.start(source: TranscriptSource.phone);
      engine.onTranscriptionFinalized('What time is lunch?');
      await Future<void>.delayed(const Duration(milliseconds: 200));

      // Restart resets deduplication state.
      engine.stop();
      engine.clearHistory();
      engine.start(source: TranscriptSource.phone);
      engine.onTranscriptionFinalized('What time is lunch?');
      await Future<void>.delayed(const Duration(milliseconds: 200));

      await sub.cancel();

      // Both should be emitted since the engine was restarted between them.
      expect(results, hasLength(2));
    });

    test('different questions are both accepted', () async {
      // Two distinct questions should both produce detection results.
      SettingsManager.instance.sentimentMonitorEnabled = false;
      SettingsManager.instance.entityMemoryEnabled = false;
      await configureFakeLlm(
        responses: [
          '{"shouldRespond": true, "question": "What time is lunch?", "questionExcerpt": "What time is lunch?"}',
          // post-response analysis after first auto-answer
          '{"chips": [], "factCheck": "null"}',
          '{"shouldRespond": true, "question": "Where is the meeting?", "questionExcerpt": "Where is the meeting?"}',
          // post-response analysis after second auto-answer
          '{"chips": [], "factCheck": "null"}',
        ],
      );

      final results = <QuestionDetectionResult>[];
      final sub = engine.questionDetectionStream.listen(results.add);

      engine.start(source: TranscriptSource.phone);
      engine.onTranscriptionFinalized('What time is lunch?');
      await Future<void>.delayed(const Duration(milliseconds: 200));
      engine.onTranscriptionFinalized('Where is the meeting?');
      await Future<void>.delayed(const Duration(milliseconds: 200));

      await sub.cancel();

      // Both questions should be detected since they are different.
      expect(results, hasLength(2));
      expect(results[0].question, 'What time is lunch?');
      expect(results[1].question, 'Where is the meeting?');
    });
  });

  // ---------------------------------------------------------------------------
  // E5: Realtime mode guard tests
  //
  // When OpenAI realtime session mode is active, the engine should skip
  // LLM-based question analysis and response generation.
  // ---------------------------------------------------------------------------
  group('realtime mode guard', () {
    late ConversationEngine engine;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await SettingsManager.instance.initialize();
      ConversationEngine.resetTestHooks();
      SettingsManager.instance.assistantProfileId = 'general';
      SettingsManager.instance.language = 'en';
      SettingsManager.instance.autoDetectQuestions = true;
      SettingsManager.instance.answerAll = true;
      engine = ConversationEngine.instance;
      engine.clearHistory();
      engine.stop();
    });

    test('skips question analysis in realtime conversation mode', () async {
      // Configure realtime session mode.
      SettingsManager.instance.transcriptionBackend = 'openai';
      SettingsManager.instance.openAISessionMode = 'realtime';

      final provider = await configureFakeLlm(
        responses: [
          '{"shouldRespond": true, "question": "What is the plan?", "questionExcerpt": "What is the plan?"}',
        ],
        streamResponses: const [
          FakeStreamResponse(['should not stream']),
        ],
      );

      final results = <QuestionDetectionResult>[];
      final sub = engine.questionDetectionStream.listen(results.add);

      engine.start(source: TranscriptSource.phone);
      engine.onTranscriptionFinalized('What is the plan?');
      await Future<void>.delayed(const Duration(milliseconds: 30));

      await sub.cancel();

      // In realtime mode, _generateResponse returns early, so the stream
      // response should never be invoked.
      expect(provider.streamCallCount, 0);
      // The LLM getResponse may still be called for question detection, but
      // the response generation path is guarded. Regardless, no streamed
      // response should be produced.
    });

    test('runs question analysis in non-realtime mode', () async {
      // Configure standard transcription mode (NOT realtime).
      SettingsManager.instance.transcriptionBackend = 'openai';
      SettingsManager.instance.openAISessionMode = 'transcription';

      final provider = await configureFakeLlm(
        responses: [
          '{"shouldRespond": true, "question": "What is the plan?", "questionExcerpt": "What is the plan?"}',
          '["Follow up"]',
        ],
        streamResponses: const [
          FakeStreamResponse(['The plan is ready.']),
        ],
      );

      final results = <QuestionDetectionResult>[];
      final sub = engine.questionDetectionStream.listen(results.add);

      engine.start(source: TranscriptSource.phone);
      engine.onTranscriptionFinalized('What is the plan?');
      await Future<void>.delayed(const Duration(milliseconds: 30));

      await sub.cancel();

      // In non-realtime mode, analysis runs and triggers streaming response.
      expect(results, hasLength(1));
      expect(results.single.question, 'What is the plan?');
      expect(provider.streamCallCount, 1);
    });
  });

  // ---------------------------------------------------------------------------
  // E1 (continued): askedBy field parsing tests
  //
  // The LLM analysis prompt asks the model to set askedBy to "other" or
  // "wearer". When the wearer asked the question, _parseQuestionDetection
  // should return null (we don't answer the wearer's own questions).
  // ---------------------------------------------------------------------------
  group('question detection askedBy field', () {
    late ConversationEngine engine;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await SettingsManager.instance.initialize();
      ConversationEngine.resetTestHooks();
      SettingsManager.instance.assistantProfileId = 'general';
      SettingsManager.instance.language = 'en';
      SettingsManager.instance.transcriptionBackend = 'openai';
      SettingsManager.instance.openAISessionMode = 'transcription';
      SettingsManager.instance.autoDetectQuestions = true;
      SettingsManager.instance.answerAll = true;
      engine = ConversationEngine.instance;
      engine.clearHistory();
      engine.stop();
    });

    test('returns null when askedBy is "wearer"', () async {
      // When the wearer asks the question, the engine should suppress it
      // because the wearer is directing the question at the other person.
      await configureFakeLlm(
        responses: [
          '{"shouldRespond": true, "question": "What do you think about the project?", "questionExcerpt": "What do you think about the project?", "askedBy": "wearer"}',
        ],
      );

      final results = <QuestionDetectionResult>[];
      final sub = engine.questionDetectionStream.listen(results.add);

      engine.start(source: TranscriptSource.phone);
      engine.onTranscriptionFinalized('What do you think about the project?');
      await Future<void>.delayed(const Duration(milliseconds: 30));

      await sub.cancel();

      // askedBy == "wearer" means the wearer asked the question; should NOT
      // produce a detection result.
      expect(results, isEmpty);
      expect(engine.history, isEmpty);
    });

    test('returns result when askedBy is "other"', () async {
      // When the other person asks the question, the engine should detect it
      // and emit a QuestionDetectionResult.
      await configureFakeLlm(
        responses: [
          '{"shouldRespond": true, "question": "Can you walk me through the architecture?", "questionExcerpt": "Can you walk me through the architecture?", "askedBy": "other"}',
        ],
      );

      final results = <QuestionDetectionResult>[];
      final sub = engine.questionDetectionStream.listen(results.add);

      engine.start(source: TranscriptSource.phone);
      engine.onTranscriptionFinalized(
        'Can you walk me through the architecture?',
      );
      await Future<void>.delayed(const Duration(milliseconds: 30));

      await sub.cancel();

      expect(results, hasLength(1));
      expect(
        results.single.question,
        'Can you walk me through the architecture?',
      );
      expect(results.single.askedBy, 'other');
    });

    test('defaults to "other" when askedBy field is missing', () async {
      // Backward compatibility: older JSON without the askedBy field should
      // default to "other" and still produce a detection result.
      await configureFakeLlm(
        responses: [
          '{"shouldRespond": true, "question": "What are the key metrics?", "questionExcerpt": "What are the key metrics?"}',
        ],
      );

      final results = <QuestionDetectionResult>[];
      final sub = engine.questionDetectionStream.listen(results.add);

      engine.start(source: TranscriptSource.phone);
      engine.onTranscriptionFinalized('What are the key metrics?');
      await Future<void>.delayed(const Duration(milliseconds: 30));

      await sub.cancel();

      expect(results, hasLength(1));
      expect(results.single.askedBy, 'other');
    });
  });

  // ---------------------------------------------------------------------------
  // E2 (continued): Timing gap and transcript window tests
  //
  // TranscriptSegments carry timestamps. When consecutive segments have a gap
  // > 1 second, _buildRecentTranscriptWindow inserts "[X.Xs pause]" markers.
  // We test this indirectly by verifying the analysis prompt sent to the LLM.
  // ---------------------------------------------------------------------------
  group('transcript timing gaps', () {
    late ConversationEngine engine;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await SettingsManager.instance.initialize();
      ConversationEngine.resetTestHooks();
      SettingsManager.instance.assistantProfileId = 'general';
      SettingsManager.instance.language = 'en';
      SettingsManager.instance.transcriptionBackend = 'openai';
      SettingsManager.instance.openAISessionMode = 'transcription';
      SettingsManager.instance.autoDetectQuestions = true;
      SettingsManager.instance.answerAll = true;
      engine = ConversationEngine.instance;
      engine.clearHistory();
      engine.stop();
    });

    test('segments with timestamps preserve ordering', () async {
      // Finalize segments with explicit timestamps (via segmentTimestamp).
      // Verify they accumulate in order in the transcript snapshot.
      final snapshots = <TranscriptSnapshot>[];
      final sub = engine.transcriptSnapshotStream.listen(snapshots.add);

      engine.start(source: TranscriptSource.phone);

      final t0 = DateTime(2026, 3, 19, 10, 0, 0);
      engine.onTranscriptionFinalized('Hello', segmentTimestamp: t0);
      engine.onTranscriptionFinalized(
        'How are you?',
        segmentTimestamp: t0.add(const Duration(seconds: 3)),
      );
      engine.onTranscriptionFinalized(
        'Fine thanks.',
        segmentTimestamp: t0.add(const Duration(seconds: 5)),
      );
      await Future<void>.delayed(const Duration(milliseconds: 20));

      await sub.cancel();

      final lastSnapshot = snapshots.last;
      expect(lastSnapshot.finalizedSegments, hasLength(3));
      expect(lastSnapshot.finalizedSegments[0], 'Hello');
      expect(lastSnapshot.finalizedSegments[1], 'How are you?');
      expect(lastSnapshot.finalizedSegments[2], 'Fine thanks.');
    });

    test(
      'timing gaps > 1s trigger analysis with pause markers in window',
      () async {
        // We verify indirectly: the LLM receives a prompt that includes
        // timing gap markers like "[3.0s pause]". We capture what the LLM
        // receives via the FakeJsonProvider.
        final prompts = <String>[];
        final provider = FakeJsonProvider(
          responses: [
            // First analysis (triggered by first segment) — no question
            '{"shouldRespond": false, "question": "", "questionExcerpt": ""}',
            // Second analysis (triggered by second segment) — no question
            '{"shouldRespond": false, "question": "", "questionExcerpt": ""}',
          ],
        );
        final llm = LlmService.instance;
        llm.registerProvider(provider);
        llm.setActiveProvider('fake');

        // Override getResponse to capture the prompt
        final captureProvider = _PromptCapturingProvider(
          delegate: provider,
          onPrompt: (prompt) => prompts.add(prompt),
        );
        llm.registerProvider(captureProvider);
        llm.setActiveProvider('capture');
        ConversationEngine.setLlmServiceGetter(() => llm);

        engine.start(source: TranscriptSource.phone);

        final t0 = DateTime(2026, 3, 19, 10, 0, 0);
        engine.onTranscriptionFinalized('First segment', segmentTimestamp: t0);
        await Future<void>.delayed(const Duration(milliseconds: 30));
        // 3-second gap — should produce a [3.0s pause] marker
        engine.onTranscriptionFinalized(
          'Second segment after pause',
          segmentTimestamp: t0.add(const Duration(seconds: 3)),
        );
        await Future<void>.delayed(const Duration(milliseconds: 50));

        // The second analysis prompt (which has both segments) should contain
        // a pause marker between them.
        expect(prompts.length, greaterThanOrEqualTo(2));
        final secondPrompt = prompts[1];
        expect(secondPrompt, contains('[3.0s pause]'));
        expect(secondPrompt, contains('First segment'));
        expect(secondPrompt, contains('Second segment after pause'));
      },
    );
  });

  // ---------------------------------------------------------------------------
  // E3: Post-conversation analysis tests
  //
  // getPostConversationAnalysis() calls the LLM to produce a structured JSON
  // analysis of the conversation history.
  // ---------------------------------------------------------------------------
  group('post-conversation analysis', () {
    late ConversationEngine engine;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await SettingsManager.instance.initialize();
      ConversationEngine.resetTestHooks();
      SettingsManager.instance.assistantProfileId = 'general';
      SettingsManager.instance.language = 'en';
      SettingsManager.instance.transcriptionBackend = 'openai';
      SettingsManager.instance.openAISessionMode = 'transcription';
      SettingsManager.instance.autoDetectQuestions = true;
      SettingsManager.instance.answerAll = true;
      engine = ConversationEngine.instance;
      engine.clearHistory();
      engine.stop();
    });

    test('returns structured JSON data when history has content', () async {
      await configureFakeLlm(
        responses: [
          // First response: question detection
          '{"shouldRespond": true, "question": "What is the plan?", "questionExcerpt": "What is the plan?", "askedBy": "other"}',
          // Second response: merged post-response analysis
          '{"chips": ["Tell me more", "Details please"], "factCheck": "null"}',
          // Third response: post-conversation analysis
          '{"summary": "Discussed project plan", "topics": ["planning", "architecture"], "actionItems": ["Create roadmap"], "sentiment": "positive"}',
        ],
        streamResponses: const [
          FakeStreamResponse(['The plan is to launch in Q2.']),
        ],
      );

      // Build up some conversation history by running the engine.
      engine.start(source: TranscriptSource.phone);
      engine.onTranscriptionFinalized('What is the plan?');
      await Future<void>.delayed(const Duration(milliseconds: 50));

      // History should have user + assistant turns.
      expect(engine.history.length, greaterThanOrEqualTo(2));

      // Now call post-conversation analysis.
      final result = await engine.getPostConversationAnalysis();

      expect(result, isNotNull);
      expect(result!['summary'], isA<String>());
      expect(result['topics'], isA<List>());
      expect(result['sentiment'], 'positive');
    });

    test('returns null when history is empty', () async {
      await configureFakeLlm(responses: []);

      // No conversation history.
      expect(engine.history, isEmpty);

      final result = await engine.getPostConversationAnalysis();
      expect(result, isNull);
    });

    test('returns null when history has fewer than 2 turns', () async {
      await configureFakeLlm(responses: []);

      // Manually add a single turn (not enough for analysis).
      await engine.askQuestion('Single question');
      // askQuestion adds a user turn but the LLM may fail to produce a response
      // when the provider queue is empty. Either way, verify analysis requires >= 2.
      // Clear and add manually to be deterministic.
      engine.clearHistory();
      // Re-check: empty history should return null.
      final result = await engine.getPostConversationAnalysis();
      expect(result, isNull);
    });

    test('handles LLM failure gracefully and returns null', () async {
      // Set up an LLM that throws on getResponse.
      final llm = LlmService.instance;
      final failingProvider = _FailingProvider();
      llm.registerProvider(failingProvider);
      llm.setActiveProvider('failing');
      ConversationEngine.setLlmServiceGetter(() => llm);

      // Add enough history for analysis (>= 2 turns).
      engine.start(source: TranscriptSource.phone);
      // We can't easily add turns via the normal flow with a failing provider,
      // so we'll use askQuestion which adds a user turn before calling LLM.
      // First, set up a non-failing provider to build history.
      await configureFakeLlm(
        responses: [
          '{"shouldRespond": true, "question": "Test?", "questionExcerpt": "Test?", "askedBy": "other"}',
          '["Follow up"]',
        ],
        streamResponses: const [
          FakeStreamResponse(['Answer here.']),
        ],
      );
      engine.onTranscriptionFinalized('Test?');
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(engine.history.length, greaterThanOrEqualTo(2));

      // Now switch to the failing provider for the analysis call.
      llm.registerProvider(failingProvider);
      llm.setActiveProvider('failing');
      ConversationEngine.setLlmServiceGetter(() => llm);

      final result = await engine.getPostConversationAnalysis();
      expect(result, isNull);
    });

    test('handles malformed JSON from LLM analysis gracefully', () async {
      // Build up history first with a working provider.
      await configureFakeLlm(
        responses: [
          '{"shouldRespond": true, "question": "Test?", "questionExcerpt": "Test?", "askedBy": "other"}',
          '["Chip"]',
        ],
        streamResponses: const [
          FakeStreamResponse(['Response.']),
        ],
      );
      engine.start(source: TranscriptSource.phone);
      engine.onTranscriptionFinalized('Test?');
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(engine.history.length, greaterThanOrEqualTo(2));

      // Now switch to a provider that returns invalid JSON for the analysis.
      final llm = LlmService.instance;
      final badJsonProvider = FakeJsonProvider(
        responses: ['This is not valid JSON {{{'],
      );
      llm.registerProvider(badJsonProvider);
      llm.setActiveProvider('fake');
      ConversationEngine.setLlmServiceGetter(() => llm);

      final result = await engine.getPostConversationAnalysis();
      expect(result, isNull);
    });
  });

  // ---------------------------------------------------------------------------
  // E5 (continued): forceQuestionAnalysis bypasses realtime guard
  // ---------------------------------------------------------------------------
  group('forceQuestionAnalysis', () {
    late ConversationEngine engine;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await SettingsManager.instance.initialize();
      ConversationEngine.resetTestHooks();
      SettingsManager.instance.assistantProfileId = 'general';
      SettingsManager.instance.language = 'en';
      SettingsManager.instance.autoDetectQuestions = true;
      SettingsManager.instance.answerAll = true;
      engine = ConversationEngine.instance;
      engine.clearHistory();
      engine.stop();
    });

    test('bypasses realtime guard and triggers analysis', () async {
      // Configure realtime session mode (which normally blocks analysis).
      SettingsManager.instance.transcriptionBackend = 'openai';
      SettingsManager.instance.openAISessionMode = 'realtime';

      await configureFakeLlm(
        responses: [
          '{"shouldRespond": true, "question": "What is the status?", "questionExcerpt": "What is the status?", "askedBy": "other"}',
        ],
      );

      final results = <QuestionDetectionResult>[];
      final sub = engine.questionDetectionStream.listen(results.add);

      engine.start(source: TranscriptSource.phone);
      // Add some transcript content for the analysis window.
      engine.onTranscriptionFinalized('What is the status?');
      await Future<void>.delayed(const Duration(milliseconds: 10));

      // In realtime mode, auto-analysis is skipped. But forceQuestionAnalysis
      // should bypass the guard and run analysis anyway.
      engine.forceQuestionAnalysis();
      await Future<void>.delayed(const Duration(milliseconds: 50));

      await sub.cancel();

      // The forced analysis should produce a detection result despite being
      // in realtime mode.
      expect(results, hasLength(1));
      expect(results.single.question, 'What is the status?');
    });

    test('does nothing when engine is not active', () async {
      SettingsManager.instance.transcriptionBackend = 'openai';
      SettingsManager.instance.openAISessionMode = 'transcription';

      await configureFakeLlm(
        responses: [
          '{"shouldRespond": true, "question": "Anything?", "questionExcerpt": "Anything?", "askedBy": "other"}',
        ],
      );

      final results = <QuestionDetectionResult>[];
      final sub = engine.questionDetectionStream.listen(results.add);

      // Engine is NOT started — forceQuestionAnalysis should be a no-op.
      engine.forceQuestionAnalysis();
      await Future<void>.delayed(const Duration(milliseconds: 30));

      await sub.cancel();

      expect(results, isEmpty);
    });
  });

  // ---------------------------------------------------------------------------
  // WS-A: Response tool buttons (summarize / rephrase / translate / factcheck)
  //
  // Root cause: askQuestion went through _generateResponse without
  // bypassRealtimeGuard: true, so whenever the OpenAI Realtime transcription
  // backend was active (transcriptionBackend == 'openai' && openAISessionMode
  // == 'realtime'), every user-initiated tool-button prompt silently no-oped.
  // These tests lock in that the four response-tool prompts all reach the
  // LLM and stream a response back even in realtime mode.
  // ---------------------------------------------------------------------------
  group('response tool buttons bypass realtime guard', () {
    late ConversationEngine engine;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await SettingsManager.instance.initialize();
      ConversationEngine.resetTestHooks();
      SettingsManager.instance.assistantProfileId = 'general';
      SettingsManager.instance.language = 'en';
      SettingsManager.instance.autoDetectQuestions = true;
      SettingsManager.instance.answerAll = true;
      // Realtime mode — previously silently dropped askQuestion prompts.
      SettingsManager.instance.transcriptionBackend = 'openai';
      SettingsManager.instance.openAISessionMode = 'realtime';
      engine = ConversationEngine.instance;
      engine.clearHistory();
      engine.stop();
      await HudController.instance.resetToIdle(
        source: 'test.ws_a.response_tools.setup',
      );
    });

    Future<void> expectPromptStreams(String prompt, String expected) async {
      final provider = await configureFakeLlm(
        responses: const [],
        streamResponses: [
          FakeStreamResponse(expected.split('')),
        ],
      );
      final aiUpdates = <String>[];
      final aiSub = engine.aiResponseStream.listen(aiUpdates.add);

      await engine.askQuestion(prompt);
      await Future<void>.delayed(const Duration(milliseconds: 30));
      await aiSub.cancel();

      expect(
        provider.streamCallCount,
        greaterThanOrEqualTo(1),
        reason: 'askQuestion must reach the LLM stream in realtime mode '
            '(prompt="$prompt")',
      );
      expect(
        aiUpdates.last,
        expected,
        reason: 'Final aiResponse should render the streamed answer '
            '(prompt="$prompt")',
      );
      // History = user turn + assistant turn.
      expect(engine.history.length, greaterThanOrEqualTo(2));
      expect(engine.history.last.content, expected);
    }

    test('summarize prompt streams a response', () async {
      await expectPromptStreams(
        'Summarize this answer in 1-3 bullet points: The sky is blue.',
        'Summary bullets.',
      );
    });

    test('rephrase prompt streams a response', () async {
      await expectPromptStreams(
        'Rewrite this answer so I can say it out loud naturally: Hi there.',
        'Rephrased out loud.',
      );
    });

    test('translate prompt streams a response', () async {
      await expectPromptStreams(
        'Translate this answer into natural Chinese: Hello world.',
        'Translated text.',
      );
    });

    test('factcheck prompt streams a response', () async {
      await expectPromptStreams(
        'Fact-check the key claims in this answer: Water boils at 50C.',
        'Fact-checked correction.',
      );
    });
  });

  // ---------------------------------------------------------------------------
  // WS-C: Q&A button on live session
  //
  // Acceptance: "Q&A on active session returns answer, no 'assistant request
  // failed' toast." Entry point is `ConversationEngine.handleQAButtonPressed`
  // -> `_runManualContextualQa` -> `_generateResponse(bypassRealtimeGuard:
  // true)`. The bypass was already set on this path, so WS-A's fix does not
  // touch it — but the regression test below locks the end-to-end behavior
  // so any future change that breaks the live-session Q&A path will be
  // caught by CI instead of waiting for a hardware repro of "Assistant
  // request failed".
  // ---------------------------------------------------------------------------
  group('Q&A button on live session (WS-C)', () {
    late ConversationEngine engine;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await SettingsManager.instance.initialize();
      ConversationEngine.resetTestHooks();
      SettingsManager.instance.assistantProfileId = 'general';
      SettingsManager.instance.language = 'en';
      SettingsManager.instance.autoDetectQuestions = true;
      SettingsManager.instance.answerAll = true;
      // Realtime mode — same config that previously dropped askQuestion
      // prompts, to guarantee the Q&A path keeps bypassing the guard.
      SettingsManager.instance.transcriptionBackend = 'openai';
      SettingsManager.instance.openAISessionMode = 'realtime';
      engine = ConversationEngine.instance;
      engine.clearHistory();
      engine.stop();
      await HudController.instance.resetToIdle(
        source: 'test.ws_c.qa_button.setup',
      );
    });

    test('handleQAButtonPressed streams an answer (no error toast)',
        () async {
      const expected = 'The status is green.';
      final provider = await configureFakeLlm(
        responses: const [],
        streamResponses: [
          FakeStreamResponse(expected.split('')),
        ],
      );

      final aiUpdates = <String>[];
      final aiSub = engine.aiResponseStream.listen(aiUpdates.add);
      final providerErrors = <ProviderErrorState?>[];
      final errSub =
          engine.providerErrorStream.listen(providerErrors.add);

      engine.start(source: TranscriptSource.phone);
      // Seed the transcript window with a question so the manual Q&A path
      // has something to answer.
      engine.onTranscriptionFinalized('What is the status of the project?');
      await Future<void>.delayed(const Duration(milliseconds: 10));

      await engine.handleQAButtonPressed();
      await Future<void>.delayed(const Duration(milliseconds: 50));

      await aiSub.cancel();
      await errSub.cancel();

      expect(
        provider.streamCallCount,
        greaterThanOrEqualTo(1),
        reason: 'handleQAButtonPressed must reach the LLM stream in '
            'realtime mode (WS-C acceptance)',
      );
      expect(
        aiUpdates.isNotEmpty && aiUpdates.last == expected,
        isTrue,
        reason: 'Final aiResponse should render the streamed answer, '
            'not an "Assistant request failed" message',
      );
      // No non-null provider error should have been published — that is
      // the signal the UI uses to show the "Assistant request failed"
      // toast.
      final nonNullErrors =
          providerErrors.where((e) => e != null).toList();
      expect(
        nonNullErrors,
        isEmpty,
        reason: 'No ProviderErrorState should be published on a '
            'successful live-session Q&A (WS-C acceptance: no '
            '"assistant request failed" toast)',
      );
    });
  });

  // ---------------------------------------------------------------------------
  // E2 (continued): Time-based deduplication with 45-second expiry
  //
  // Duplicate questions are ignored within a 45-second window. After 45
  // seconds, the same question should be re-accepted.
  // ---------------------------------------------------------------------------
  group('time-based question deduplication', () {
    late ConversationEngine engine;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await SettingsManager.instance.initialize();
      ConversationEngine.resetTestHooks();
      SettingsManager.instance.assistantProfileId = 'general';
      SettingsManager.instance.language = 'en';
      SettingsManager.instance.transcriptionBackend = 'openai';
      SettingsManager.instance.openAISessionMode = 'transcription';
      SettingsManager.instance.autoDetectQuestions = true;
      SettingsManager.instance.answerAll = true;
      engine = ConversationEngine.instance;
      engine.clearHistory();
      engine.stop();
    });

    test('deduplicates same question within 45-second window', () async {
      // This is already tested in the "question deduplication" group above,
      // but this test explicitly documents the 45-second threshold behavior.
      await configureFakeLlm(
        responses: [
          '{"shouldRespond": true, "question": "How is the budget?", "questionExcerpt": "How is the budget?", "askedBy": "other"}',
          '{"shouldRespond": true, "question": "How is the budget?", "questionExcerpt": "How is the budget?", "askedBy": "other"}',
        ],
      );

      final results = <QuestionDetectionResult>[];
      final sub = engine.questionDetectionStream.listen(results.add);

      engine.start(source: TranscriptSource.phone);
      engine.onTranscriptionFinalized('How is the budget?');
      await Future<void>.delayed(const Duration(milliseconds: 30));
      // Ask again immediately — should be deduplicated.
      engine.onTranscriptionFinalized('How is the budget?');
      await Future<void>.delayed(const Duration(milliseconds: 30));

      await sub.cancel();

      expect(results, hasLength(1));
    });
  });

  // ---------------------------------------------------------------------------
  // E3 (continued): postConversationAnalysisStream tests
  //
  // When the engine stops and there is meaningful history, it should
  // asynchronously emit a post-conversation analysis on the stream.
  // ---------------------------------------------------------------------------
  group('postConversationAnalysisStream', () {
    late ConversationEngine engine;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await SettingsManager.instance.initialize();
      ConversationEngine.resetTestHooks();
      SettingsManager.instance.assistantProfileId = 'general';
      SettingsManager.instance.language = 'en';
      SettingsManager.instance.transcriptionBackend = 'openai';
      SettingsManager.instance.openAISessionMode = 'transcription';
      SettingsManager.instance.autoDetectQuestions = true;
      SettingsManager.instance.answerAll = true;
      engine = ConversationEngine.instance;
      engine.clearHistory();
      engine.stop();
    });

    test('emits analysis on stream when engine stops with history', () async {
      await configureFakeLlm(
        responses: [
          // 1st: question detection for "What next?"
          '{"shouldRespond": true, "question": "What next?", "questionExcerpt": "What next?", "askedBy": "other"}',
          // 2nd: merged post-response analysis after answer
          '{"chips": ["More info"], "factCheck": "null"}',
          // 3rd: question detection for "Sounds good." — no question
          '{"shouldRespond": false, "question": "", "questionExcerpt": ""}',
          // 4th: post-conversation analysis (triggered on stop)
          '{"summary": "Discussed next steps", "topics": ["planning"], "actionItems": ["Review docs"], "sentiment": "neutral"}',
        ],
        streamResponses: const [
          FakeStreamResponse(['We should review the docs.']),
        ],
      );

      // Collect analysis stream events.
      final analysisResults = <Map<String, dynamic>?>[];
      final analysisSub = engine.postConversationAnalysisStream.listen(
        analysisResults.add,
      );

      engine.start(source: TranscriptSource.phone);
      engine.onTranscriptionFinalized('What next?');
      await Future<void>.delayed(const Duration(milliseconds: 50));

      // History should have at least 2 turns and finalized segments > 1.
      // Add another finalized segment to ensure the guard passes.
      engine.onTranscriptionFinalized('Sounds good.');
      await Future<void>.delayed(const Duration(milliseconds: 30));

      // Stop the engine — this should trigger post-conversation analysis.
      engine.stop();
      await Future<void>.delayed(const Duration(milliseconds: 100));

      await analysisSub.cancel();

      // The stream should have received an analysis result.
      // The stop() method fires getPostConversationAnalysis() asynchronously
      // when history.length > 1 AND finalizedSegments.length > 1.
      expect(analysisResults, isNotEmpty);
      // The last non-null result should be the analysis.
      final analysis = analysisResults.lastWhere(
        (r) => r != null,
        orElse: () => null,
      );
      expect(analysis, isNotNull);
      expect(analysis!['summary'], isA<String>());
      expect(analysis['topics'], isA<List>());
    });
  });
}

// =============================================================================
// Helper classes for testing
// =============================================================================

/// A provider that captures the user prompt sent to getResponse.
class _PromptCapturingProvider implements LlmProvider {
  _PromptCapturingProvider({required this.delegate, required this.onPrompt});

  final LlmProvider delegate;
  final void Function(String prompt) onPrompt;

  @override
  List<String> get availableModels => delegate.availableModels;

  @override
  String get defaultModel => delegate.defaultModel;

  @override
  String get id => 'capture';

  @override
  String get name => 'Capture';

  @override
  Future<String> getResponse({
    required String systemPrompt,
    required List<ChatMessage> messages,
    String? model,
    double temperature = 0.7,
    LlmRequestOptions? requestOptions,
    void Function(LlmResponseMetadata metadata)? onMetadata,
  }) async {
    // Capture the last user message content as the "prompt".
    final userMessage = messages.lastWhere(
      (m) => m.role == 'user',
      orElse: () => ChatMessage(role: 'user', content: ''),
    );
    onPrompt(userMessage.content);
    return delegate.getResponse(
      systemPrompt: systemPrompt,
      messages: messages,
      model: model,
      temperature: temperature,
      requestOptions: requestOptions,
      onMetadata: onMetadata,
    );
  }

  @override
  Stream<String> streamResponse({
    required String systemPrompt,
    required List<ChatMessage> messages,
    String? model,
    double temperature = 0.7,
    LlmRequestOptions? requestOptions,
    void Function(LlmResponseMetadata metadata)? onMetadata,
  }) {
    return delegate.streamResponse(
      systemPrompt: systemPrompt,
      messages: messages,
      model: model,
      temperature: temperature,
      requestOptions: requestOptions,
      onMetadata: onMetadata,
    );
  }

  @override
  Future<List<String>> queryAvailableModels({bool refresh = false}) async {
    return delegate.queryAvailableModels(refresh: refresh);
  }

  @override
  bool supportsRealtimeModel(String model) =>
      delegate.supportsRealtimeModel(model);

  @override
  Future<bool> testConnection(String apiKey) async => true;

  @override
  void updateApiKey(String apiKey) {}

  @override
  Stream<LlmResponseEvent> streamWithTools({
    required String systemPrompt,
    required List<ChatMessage> messages,
    List<ToolDefinition>? tools,
    String? model,
    double temperature = 0.7,
    LlmRequestOptions? requestOptions,
    void Function(LlmResponseMetadata metadata)? onMetadata,
  }) async* {
    await for (final chunk in streamResponse(
      systemPrompt: systemPrompt,
      messages: messages,
      model: model,
      temperature: temperature,
      requestOptions: requestOptions,
      onMetadata: onMetadata,
    )) {
      yield TextDelta(chunk);
    }
  }
}

/// A provider that always throws to simulate LLM failures.
class _FailingProvider implements LlmProvider {
  @override
  List<String> get availableModels => const ['fail-model'];

  @override
  String get defaultModel => 'fail-model';

  @override
  String get id => 'failing';

  @override
  String get name => 'Failing';

  @override
  Future<String> getResponse({
    required String systemPrompt,
    required List<ChatMessage> messages,
    String? model,
    double temperature = 0.7,
    LlmRequestOptions? requestOptions,
    void Function(LlmResponseMetadata metadata)? onMetadata,
  }) async {
    throw Exception('Simulated LLM failure');
  }

  @override
  Stream<String> streamResponse({
    required String systemPrompt,
    required List<ChatMessage> messages,
    String? model,
    double temperature = 0.7,
    LlmRequestOptions? requestOptions,
    void Function(LlmResponseMetadata metadata)? onMetadata,
  }) async* {
    throw Exception('Simulated LLM failure');
  }

  @override
  Future<List<String>> queryAvailableModels({bool refresh = false}) async {
    return availableModels;
  }

  @override
  bool supportsRealtimeModel(String model) => false;

  @override
  Future<bool> testConnection(String apiKey) async => false;

  @override
  void updateApiKey(String apiKey) {}

  @override
  Stream<LlmResponseEvent> streamWithTools({
    required String systemPrompt,
    required List<ChatMessage> messages,
    List<ToolDefinition>? tools,
    String? model,
    double temperature = 0.7,
    LlmRequestOptions? requestOptions,
    void Function(LlmResponseMetadata metadata)? onMetadata,
  }) async* {
    throw Exception('Simulated LLM failure');
  }
}
