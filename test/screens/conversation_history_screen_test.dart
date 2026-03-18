import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_helix/screens/conversation_history_screen.dart';
import 'package:flutter_helix/services/conversation_engine.dart';
import 'package:flutter_helix/services/llm/llm_provider.dart';
import 'package:flutter_helix/services/llm/llm_service.dart';
import 'package:flutter_helix/services/settings_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeStreamResponse {
  const _FakeStreamResponse(this.chunks);

  final List<String> chunks;
}

class _FakeJsonProvider implements LlmProvider {
  _FakeJsonProvider({
    List<String> responses = const [],
    List<_FakeStreamResponse> streamResponses = const [],
  }) : _responses = Queue<String>.from(responses),
       _streamResponses = Queue<_FakeStreamResponse>.from(streamResponses);

  final Queue<String> _responses;
  final Queue<_FakeStreamResponse> _streamResponses;

  @override
  List<String> get availableModels => const ['fake-model'];

  @override
  String get defaultModel => 'fake-model';

  @override
  String get id => 'fake-history';

  @override
  String get name => 'Fake History';

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
    final script = _streamResponses.isEmpty
        ? const _FakeStreamResponse(['stubbed answer'])
        : _streamResponses.removeFirst();
    for (final chunk in script.chunks) {
      yield chunk;
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

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await SettingsManager.instance.initialize();
    LlmService.instance.initializeDefaults();
  });

  setUp(() {
    ConversationEngine.resetTestHooks();
    ConversationEngine.instance.clearHistory();
    ConversationEngine.instance.stop();
    SettingsManager.instance.assistantProfileId = 'professional';
    SettingsManager.instance.language = 'en';
  });

  testWidgets(
    'conversation history surfaces review briefs from session metadata',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1600, 2400));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final llm = LlmService.instance;
      llm.registerProvider(
        _FakeJsonProvider(
          responses: const ['["Keep going"]'],
          streamResponses: const [
            _FakeStreamResponse([
              'Please review the roadmap and verify the 120000 budget figure.',
            ]),
          ],
        ),
      );
      llm.setActiveProvider('fake-history');
      ConversationEngine.setLlmServiceGetter(() => llm);

      final engine = ConversationEngine.instance;
      await engine.askQuestion(
        'We should review the Q2 plan, send the follow-up deck, and confirm the budget is 120000.',
      );

      await tester.pumpWidget(
        const MaterialApp(home: ConversationHistoryScreen()),
      );
      await tester.pumpAndSettle();

      expect(find.text('Copy brief'), findsOneWidget);
      expect(find.textContaining('review signals'), findsWidgets);
      expect(find.text('Copy summary'), findsOneWidget);
      expect(find.text('Copy action items'), findsOneWidget);
    },
  );
}
