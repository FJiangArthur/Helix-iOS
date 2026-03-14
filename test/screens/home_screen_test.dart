import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_helix/screens/home_screen.dart';
import 'package:flutter_helix/services/conversation_engine.dart';
import 'package:flutter_helix/services/llm/llm_provider.dart';
import 'package:flutter_helix/services/llm/llm_service.dart';
import 'package:flutter_helix/services/settings_manager.dart';
import 'package:flutter_helix/theme/helix_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeJsonProvider implements LlmProvider {
  _FakeJsonProvider(List<String> responses)
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

  const secureStorageChannel = MethodChannel(
    'plugins.it_nomads.com/flutter_secure_storage',
  );
  final secureStorageValues = <String, String>{};

  Future<Object?> secureStorageHandler(MethodCall call) async {
    final arguments = (call.arguments as Map?)?.cast<Object?, Object?>() ?? {};
    final key = arguments['key'] as String?;

    switch (call.method) {
      case 'read':
        return key == null ? null : secureStorageValues[key];
      case 'write':
        final value = arguments['value'] as String?;
        if (key != null && value != null) {
          secureStorageValues[key] = value;
        }
        return null;
      case 'delete':
        if (key != null) {
          secureStorageValues.remove(key);
        }
        return null;
      case 'deleteAll':
        secureStorageValues.clear();
        return null;
      case 'containsKey':
        return key != null && secureStorageValues.containsKey(key);
      case 'readAll':
        return Map<String, String>.from(secureStorageValues);
      default:
        return null;
    }
  }

  setUpAll(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(secureStorageChannel, secureStorageHandler);
    SharedPreferences.setMockInitialValues({});
    await SettingsManager.instance.initialize();
    LlmService.instance.initializeDefaults();
  });

  tearDownAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(secureStorageChannel, null);
  });

  setUp(() {
    secureStorageValues.clear();
    ConversationEngine.instance.clearHistory();
    ConversationEngine.instance.stop();
    SettingsManager.instance.activeProviderId = 'openai';
    SettingsManager.instance.assistantProfileId = 'general';
    SettingsManager.instance.defaultQuickAskPreset = 'concise';
    SettingsManager.instance.language = 'en';
    SettingsManager.instance.autoShowFollowUps = true;
    SettingsManager.instance.autoShowSummary = true;
  });

  testWidgets('home screen uses compact overview and fixed composer dock', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: HomeScreen())),
    );
    await tester.pump();

    expect(find.text('Conversation Hub'), findsOneWidget);
    expect(find.text('Expand'), findsOneWidget);
    expect(find.text('Tune'), findsOneWidget);
    expect(
      find.text('Keep the prompt, answer, and voice controls in one place'),
      findsNothing,
    );
    expect(find.byKey(const Key('home-quick-start-strip')), findsOneWidget);
    expect(find.byKey(const Key('home-fixed-composer-dock')), findsOneWidget);
    expect(find.byKey(const Key('home-composer-input-shell')), findsOneWidget);
    expect(find.byKey(const Key('home-composer-send-button')), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const Key('home-fixed-composer-dock')),
        matching: find.byType(TextField),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('home-fixed-composer-dock')),
        matching: find.text('Listen'),
      ),
      findsNothing,
    );
    expect(find.text('PHONE ANSWER'), findsNothing);

    final composerElement = tester.element(
      find.byKey(const Key('home-fixed-composer-dock')),
    );
    var hasScrollAncestor = false;
    composerElement.visitAncestorElements((element) {
      if (element.widget is SingleChildScrollView) {
        hasScrollAncestor = true;
      }
      return true;
    });
    expect(hasScrollAncestor, isFalse);
  });

  test('navigation theme is compact and icons only', () {
    final navigationBar = HelixTheme.darkTheme.navigationBarTheme;
    expect(
      navigationBar.labelBehavior,
      NavigationDestinationLabelBehavior.alwaysHide,
    );
    expect(navigationBar.height, 56);
  });

  testWidgets(
    'home screen keeps transcript visible while active transcription and phone answer appear',
    (tester) async {
      final llm = LlmService.instance;
      llm.registerProvider(
        _FakeJsonProvider([
          '{"shouldRespond": true, "question": "Can you explain the plan?", "answerForPhone": "Here is the concise answer.", "answerForGlasses": "Concise HUD answer."}',
          '["Tell me more"]',
        ]),
      );
      llm.setActiveProvider('fake');
      ConversationEngine.setLlmServiceGetter(() => llm);

      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: HomeScreen())),
      );
      await tester.pump();

      final engine = ConversationEngine.instance;
      engine.start(source: TranscriptSource.phone);
      engine.onTranscriptionUpdate('Can you explain the plan?');
      engine.onTranscriptionFinalized('Can you explain the plan?');

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 30));

      expect(find.textContaining('Can you explain the plan?'), findsWidgets);
      expect(find.text('ACTIVE TRANSCRIPTION'), findsOneWidget);
      expect(find.text('DETECTED QUESTION'), findsOneWidget);
      expect(find.text('PHONE ANSWER'), findsOneWidget);
      expect(find.textContaining('Here is the concise answer.'), findsWidgets);

      engine.stop();
      await tester.pump();
    },
  );

  testWidgets('home screen localizes live transcription labels in Japanese', (
    tester,
  ) async {
    SettingsManager.instance.language = 'ja';

    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: HomeScreen())),
    );
    await tester.pump();

    final engine = ConversationEngine.instance;
    engine.start(source: TranscriptSource.phone);
    engine.onTranscriptionUpdate('計画を説明してくれますか？');
    engine.onTranscriptionFinalized('計画を説明してくれますか？');

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 30));

    expect(find.text('ライブ文字起こし'), findsOneWidget);
    expect(find.text('スマホ入力'), findsOneWidget);

    engine.stop();
    await tester.pump();
  });
}
