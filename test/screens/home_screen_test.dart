import 'dart:async';
import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_helix/ble_manager.dart';
import 'package:flutter_helix/models/assistant_profile.dart';
import 'package:flutter_helix/screens/home_screen.dart';
import 'package:flutter_helix/services/conversation_engine.dart';
import 'package:flutter_helix/services/llm/llm_provider.dart';
import 'package:flutter_helix/services/llm/llm_service.dart';
import 'package:flutter_helix/services/settings_manager.dart';
import 'package:flutter_helix/theme/helix_theme.dart';
import 'package:flutter_helix/widgets/home_assistant_modules.dart';
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
    final script = _streamResponses.isEmpty
        ? const _FakeStreamResponse(['stubbed stream response'])
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

  const secureStorageChannel = MethodChannel(
    'plugins.it_nomads.com/flutter_secure_storage',
  );
  const bluetoothChannel = MethodChannel('method.bluetooth');
  final secureStorageValues = <String, String>{};
  final bluetoothMethodCalls = <MethodCall>[];

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
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(bluetoothChannel, (call) async {
          bluetoothMethodCalls.add(call);
          switch (call.method) {
            case 'startEvenAI':
              return 'started';
            case 'stopEvenAI':
              return 'stopped';
            default:
              return null;
          }
        });
    SharedPreferences.setMockInitialValues({});
    await SettingsManager.instance.initialize();
    LlmService.instance.initializeDefaults();
  });

  tearDownAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(secureStorageChannel, null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(bluetoothChannel, null);
  });

  setUp(() async {
    secureStorageValues.clear();
    bluetoothMethodCalls.clear();
    ConversationEngine.resetTestHooks();
    ConversationEngine.instance.clearHistory();
    ConversationEngine.instance.stop();
    ConversationEngine.instance.setMode(ConversationMode.general);
    BleManager.get().debugSetConnectionState(
      leftConnected: false,
      rightConnected: false,
    );
    for (final profile in AssistantProfile.defaults) {
      await SettingsManager.instance.saveAssistantProfile(profile);
    }
    SettingsManager.instance
      ..activeProviderId = 'openai'
      ..assistantProfileId = 'general'
      ..defaultQuickAskPreset = 'concise'
      ..language = 'en'
      ..uiLanguage = 'en'
      ..autoDetectQuestions = true
      ..autoAnswerQuestions = true
      ..autoShowFollowUps = true
      ..autoShowSummary = true
      ..preferredMicSource = 'auto';
    await SettingsManager.instance.save();
  });

  testWidgets('home screen uses compact overview and fixed composer dock', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: HomeScreen())),
    );
    await tester.pump();

    expect(find.text('CONTROL DECK'), findsOneWidget);
    expect(find.text('CONVERSATION HUB'), findsOneWidget);
    expect(find.text('Expand'), findsNothing);
    expect(find.text('Tune'), findsOneWidget);
    expect(
      find.text('Keep the prompt, answer, and voice controls in one place'),
      findsNothing,
    );
    expect(find.byKey(const Key('home-quick-start-strip')), findsOneWidget);
    expect(find.byKey(const Key('home-fixed-composer-dock')), findsOneWidget);
    expect(find.byKey(const Key('home-composer-input-shell')), findsOneWidget);
    expect(find.byKey(const Key('home-composer-send-button')), findsOneWidget);
    expect(find.byKey(const Key('home-session-loadout-card')), findsOneWidget);
    expect(find.text('READY STACK'), findsOneWidget);
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

  testWidgets('assistant setup sheet tunes profile tooling and auto surfaces', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: HomeScreen())),
    );
    await tester.pump();

    await tester.tap(find.text('Tune'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('home-setup-preview-card')), findsOneWidget);
    expect(
      find.byKey(const Key('home-setup-tool-summary-toggle')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('home-setup-auto-summary-toggle')),
      findsOneWidget,
    );

    expect(
      SettingsManager.instance
          .resolveAssistantProfile('general')
          .showSummaryTool,
      isTrue,
    );
    final summaryToggle = tester.widget<AssistantSettingsToggleTile>(
      find.byKey(const Key('home-setup-tool-summary-toggle')),
    );
    await summaryToggle.onTap();
    await tester.pumpAndSettle();
    expect(
      SettingsManager.instance
          .resolveAssistantProfile('general')
          .showSummaryTool,
      isFalse,
    );

    final autoSummaryToggle = tester.widget<AssistantSettingsToggleTile>(
      find.byKey(const Key('home-setup-auto-summary-toggle')),
    );
    await autoSummaryToggle.onTap();
    await tester.pumpAndSettle();
    expect(SettingsManager.instance.autoShowSummary, isFalse);
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
        _FakeJsonProvider(
          responses: [
            '{"shouldRespond": true, "question": "Can you explain the plan?", "questionExcerpt": "Can you explain the plan?"}',
            '{"chips": ["Tell me more"], "factCheck": "OK"}',
          ],
          streamResponses: const [
            _FakeStreamResponse(['Here is ', 'the concise answer.']),
          ],
        ),
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
      expect(find.byKey(const Key('home-response-tools-card')), findsOneWidget);
      expect(find.byKey(const Key('home-follow-up-chip-deck')), findsOneWidget);
      expect(find.text('RESPONSE TOOLS'), findsOneWidget);
      expect(find.text('FOLLOW-UP DECK'), findsOneWidget);
      expect(find.text('Tell me more'), findsOneWidget);

      engine.stop();
      BleManager.get().stopSendBeatHeart();
      await tester.pump();
    },
  );

  testWidgets(
    'home screen mic honors phone override even when glasses are connected',
    (tester) async {
      BleManager.get().debugSetConnectionState(
        leftConnected: true,
        rightConnected: true,
      );
      SettingsManager.instance.preferredMicSource = 'phone';

      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: HomeScreen())),
      );
      await tester.pump();

      // Start engine directly to avoid RecordingCoordinator platform deps
      final engine = ConversationEngine.instance;
      engine.start(source: TranscriptSource.phone);
      engine.onTranscriptionUpdate('Hello there');
      engine.onTranscriptionFinalized('Hello there');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 30));

      expect(find.text('PHONE INPUT'), findsWidgets);
      expect(find.text('G1 OUTPUT ONLY'), findsWidgets);

      BleManager.get().debugSetConnectionState(
        leftConnected: false,
        rightConnected: false,
      );
      engine.stop();
      BleManager.get().stopSendBeatHeart();
      await tester.pump();
    },
  );

  testWidgets(
    'home screen updates quick-start suggestions when the mode changes',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: HomeScreen())),
      );
      await tester.pump();

      expect(ConversationEngine.instance.mode, ConversationMode.general);
      expect(find.text('How do I start a good conversation?'), findsOneWidget);
      expect(find.text('Tell me about yourself'), findsNothing);

      ConversationEngine.instance.setMode(ConversationMode.interview);
      await tester.pumpAndSettle();
      expect(ConversationEngine.instance.mode, ConversationMode.interview);
      expect(find.text('How do I start a good conversation?'), findsNothing);
      expect(find.text('Tell me about yourself'), findsOneWidget);

      ConversationEngine.instance.setMode(ConversationMode.general);
      await tester.pumpAndSettle();
      expect(ConversationEngine.instance.mode, ConversationMode.general);
      expect(find.text('How do I start a good conversation?'), findsOneWidget);
      expect(find.text('Tell me about yourself'), findsNothing);
    },
  );

  testWidgets('home screen localizes live transcription labels in Japanese', (
    tester,
  ) async {
    SettingsManager.instance.language = 'ja';
    SettingsManager.instance.uiLanguage = 'ja';
    SettingsManager.instance.autoDetectQuestions = false;

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
    expect(find.text('スマホ入力'), findsWidgets);

    engine.stop();
    BleManager.get().stopSendBeatHeart();
    await tester.pump();
  });

  testWidgets('home screen exposes proactive mode and an analyze action', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: HomeScreen())),
    );
    await tester.pump();

    expect(find.text('Proactive'), findsOneWidget);

    await tester.tap(find.text('Proactive'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('home-analyze-button')), findsOneWidget);
    expect(find.text('Analyze'), findsOneWidget);
  });
}
