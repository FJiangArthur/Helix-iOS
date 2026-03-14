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

class FakeJsonProvider implements LlmProvider {
  FakeJsonProvider(List<String> responses)
    : _responses = Queue<String>.from(responses);

  final Queue<String> _responses;

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
      return '{"shouldRespond": false, "question": "", "answerForPhone": "", "answerForGlasses": ""}';
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
    yield 'stubbed stream response';
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

  Future<LlmService> configureFakeLlm(List<String> responses) async {
    final llm = LlmService.instance;
    llm.registerProvider(FakeJsonProvider(responses));
    llm.setActiveProvider('fake');
    return llm;
  }

  group('ConversationEngine quick ask error handling', () {
    late ConversationEngine engine;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await SettingsManager.instance.initialize();
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
        final aiResponseFuture = engine.aiResponseStream.first;
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
      SettingsManager.instance.assistantProfileId = 'general';
      SettingsManager.instance.language = 'en';
      engine = ConversationEngine.instance;
      engine.clearHistory();
      engine.stop();
    });

    test(
      'partial and final transcript snapshots are emitted with source state',
      () async {
        final llm = await configureFakeLlm([
          '{"shouldRespond": false, "question": "", "answerForPhone": "", "answerForGlasses": ""}',
        ]);
        ConversationEngine.setLlmServiceGetter(() => llm);

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
      final llm = await configureFakeLlm([
        '{"shouldRespond": false, "question": "", "answerForPhone": "", "answerForGlasses": ""}',
      ]);
      ConversationEngine.setLlmServiceGetter(() => llm);

      final results = <QuestionAnalysisResult>[];
      final sub = engine.questionAnalysisStream.listen(results.add);

      engine.start(source: TranscriptSource.phone);
      engine.onTranscriptionFinalized('Nice weather today.');
      await Future<void>.delayed(const Duration(milliseconds: 20));

      await sub.cancel();

      expect(results, isEmpty);
      expect(engine.history, isEmpty);
    });

    test(
      'duplicate questions are ignored after the first handled result',
      () async {
        final llm = await configureFakeLlm([
          '{"shouldRespond": true, "question": "What time is the meeting?", "answerForPhone": "It starts at 3 PM.", "answerForGlasses": "Meeting starts at 3 PM."}',
          '["Tell me more"]',
          '{"shouldRespond": true, "question": "What time is the meeting?", "answerForPhone": "It starts at 3 PM.", "answerForGlasses": "Meeting starts at 3 PM."}',
        ]);
        ConversationEngine.setLlmServiceGetter(() => llm);

        final results = <QuestionAnalysisResult>[];
        final sub = engine.questionAnalysisStream.listen(results.add);

        engine.start(source: TranscriptSource.phone);
        engine.onTranscriptionFinalized('What time is the meeting?');
        await Future<void>.delayed(const Duration(milliseconds: 20));
        engine.onTranscriptionFinalized('What time is the meeting?');
        await Future<void>.delayed(const Duration(milliseconds: 20));

        await sub.cancel();

        expect(results.length, 1);
        expect(results.single.question, 'What time is the meeting?');
        expect(engine.history.length, 2);
        expect(engine.history.first.content, 'What time is the meeting?');
        expect(engine.history.last.content, 'It starts at 3 PM.');
      },
    );
  });
}
