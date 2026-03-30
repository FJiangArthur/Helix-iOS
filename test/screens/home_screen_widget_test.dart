import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_helix/ble_manager.dart';
import 'package:flutter_helix/models/assistant_profile.dart';
import 'package:flutter_helix/screens/home_screen.dart';
import 'package:flutter_helix/services/conversation_engine.dart';
import 'package:flutter_helix/services/llm/llm_service.dart';
import 'package:flutter_helix/services/settings_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const secureStorageChannel = MethodChannel(
    'plugins.it_nomads.com/flutter_secure_storage',
  );
  const bluetoothChannel = MethodChannel('method.bluetooth');
  final secureStorageValues = <String, String>{};

  Future<Object?> secureStorageHandler(MethodCall call) async {
    final arguments =
        (call.arguments as Map?)?.cast<Object?, Object?>() ?? {};
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
        if (key != null) secureStorageValues.remove(key);
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
    ConversationEngine.resetTestHooks();
    ConversationEngine.instance.clearHistory();
    ConversationEngine.instance.stop();
    ConversationEngine.instance.setMode(ConversationMode.general);
    BleManager.get().isConnected = false;
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

  group('HomeScreen widget rendering', () {
    testWidgets('renders without errors', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: HomeScreen())),
      );
      await tester.pump();

      expect(find.byType(HomeScreen), findsOneWidget);
    });

    testWidgets('displays control deck and conversation hub headers', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: HomeScreen())),
      );
      await tester.pump();

      expect(find.text('CONTROL DECK'), findsOneWidget);
      expect(find.text('CONVERSATION HUB'), findsOneWidget);
    });

    testWidgets('composer dock with text field is present', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: HomeScreen())),
      );
      await tester.pump();

      expect(
        find.byKey(const Key('home-fixed-composer-dock')),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const Key('home-fixed-composer-dock')),
          matching: find.byType(TextField),
        ),
        findsOneWidget,
      );
    });

    testWidgets('send button is present in composer dock', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: HomeScreen())),
      );
      await tester.pump();

      expect(
        find.byKey(const Key('home-composer-send-button')),
        findsOneWidget,
      );
    });

    testWidgets('composer input shell is present', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: HomeScreen())),
      );
      await tester.pump();

      expect(
        find.byKey(const Key('home-composer-input-shell')),
        findsOneWidget,
      );
    });

    testWidgets('quick start strip is present', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: HomeScreen())),
      );
      await tester.pump();

      expect(
        find.byKey(const Key('home-quick-start-strip')),
        findsOneWidget,
      );
    });

    testWidgets('session loadout card (READY STACK) is present', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: HomeScreen())),
      );
      await tester.pump();

      expect(
        find.byKey(const Key('home-session-loadout-card')),
        findsOneWidget,
      );
      expect(find.text('READY STACK'), findsOneWidget);
    });

    testWidgets('Tune control is visible and Expand is absent', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: HomeScreen())),
      );
      await tester.pump();

      expect(find.text('Tune'), findsOneWidget);
      expect(find.text('Expand'), findsNothing);
    });

    testWidgets('quick-start suggestions follow the current mode', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: HomeScreen())),
      );
      await tester.pump();

      expect(
        find.text('How do I start a good conversation?'),
        findsOneWidget,
      );
      expect(find.text('Tell me about yourself'), findsNothing);

      ConversationEngine.instance.setMode(ConversationMode.interview);
      await tester.pumpAndSettle();

      expect(find.text('How do I start a good conversation?'), findsNothing);
      expect(find.text('Tell me about yourself'), findsOneWidget);
    });

    testWidgets(
      'summary and topics sections are NOT shown at idle (regression)',
      (tester) async {
        await tester.pumpWidget(
          const MaterialApp(home: Scaffold(body: HomeScreen())),
        );
        await tester.pump();

        // At idle, no conversation summary or follow-up chips should appear
        expect(
          find.byKey(const Key('home-conversation-summary-card')),
          findsNothing,
        );
        expect(
          find.byKey(const Key('home-follow-up-chip-deck')),
          findsNothing,
        );
      },
    );

    testWidgets('response tools card is NOT shown at idle', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: HomeScreen())),
      );
      await tester.pump();

      expect(
        find.byKey(const Key('home-response-tools-card')),
        findsNothing,
      );
    });

    testWidgets('insights card is NOT shown at idle', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: HomeScreen())),
      );
      await tester.pump();

      expect(find.byKey(const Key('home-insights-card')), findsNothing);
    });

    testWidgets('PHONE ANSWER label is not shown at idle', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: HomeScreen())),
      );
      await tester.pump();

      expect(find.text('PHONE ANSWER'), findsNothing);
    });

    testWidgets('composer dock is NOT inside a scroll view', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: HomeScreen())),
      );
      await tester.pump();

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
  });
}
