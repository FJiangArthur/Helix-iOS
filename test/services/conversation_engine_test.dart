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
      SettingsManager.instance.autoDetectQuestions = true;
      SettingsManager.instance.autoAnswerQuestions = true;
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
}
