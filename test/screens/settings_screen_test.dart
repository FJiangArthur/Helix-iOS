import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_helix/ble_manager.dart';
import 'package:flutter_helix/models/assistant_profile.dart';
import 'package:flutter_helix/screens/settings_screen.dart';
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
      ..autoDetectQuestions = true
      ..autoAnswerQuestions = true
      ..autoShowFollowUps = true
      ..autoShowSummary = true
      ..preferredMicSource = 'auto';
    await SettingsManager.instance.save();
  });

  group('SettingsScreen widget rendering', () {
    testWidgets('renders without errors', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: SettingsScreen())),
      );
      await tester.pump();

      expect(find.byType(SettingsScreen), findsOneWidget);
    });

    testWidgets('AI Provider section is present', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: SettingsScreen())),
      );
      await tester.pump();

      // Section titles are rendered in uppercase
      expect(find.text('AI PROVIDER'), findsOneWidget);
    });

    testWidgets('Conversation section is present', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: SettingsScreen())),
      );
      await tester.pump();

      expect(find.text('CONVERSATION'), findsOneWidget);
    });

    testWidgets('Transcription section is present', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: SettingsScreen())),
      );
      await tester.pump();

      expect(find.text('TRANSCRIPTION'), findsOneWidget);
    });

    testWidgets('Assistant Defaults section is present', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: SettingsScreen())),
      );
      await tester.pump();

      expect(find.text('ASSISTANT DEFAULTS'), findsOneWidget);
    });

    testWidgets('Auto-detect Questions toggle exists', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: SettingsScreen())),
      );
      await tester.pump();

      expect(find.text('Auto-detect Questions'), findsOneWidget);
    });

    testWidgets('Auto-answer toggle exists', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: SettingsScreen())),
      );
      await tester.pump();

      expect(find.text('Auto-answer'), findsOneWidget);
    });

    testWidgets('Language selector is present', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: SettingsScreen())),
      );
      await tester.pump();

      expect(find.text('Language'), findsOneWidget);
    });

    testWidgets('Microphone setting is present', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: SettingsScreen())),
      );
      await tester.pump();

      expect(find.text('Microphone'), findsOneWidget);
    });

    testWidgets('Backend dropdown is present in Transcription section', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: SettingsScreen())),
      );
      await tester.pump();

      expect(find.text('Backend'), findsOneWidget);
    });

    testWidgets('Auto-show Summary toggle exists', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: SettingsScreen())),
      );
      await tester.pump();

      expect(find.text('Auto-show Summary'), findsOneWidget);
    });

    testWidgets('Auto-show Follow-ups toggle exists', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: SettingsScreen())),
      );
      await tester.pump();

      expect(find.text('Auto-show Follow-ups'), findsOneWidget);
    });

    testWidgets('settings screen is scrollable', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: SettingsScreen())),
      );
      await tester.pump();

      expect(find.byType(SingleChildScrollView), findsOneWidget);
    });

    testWidgets('Assistant Profiles section is present', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: SettingsScreen())),
      );
      await tester.pump();

      expect(find.text('ASSISTANT PROFILES'), findsOneWidget);
    });

    testWidgets('Glasses section is present', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 2400));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: SettingsScreen())),
      );
      await tester.pump();

      // Scroll down to find the Glasses section
      await tester.dragUntilVisible(
        find.text('GLASSES'),
        find.byType(SingleChildScrollView),
        const Offset(0, -300),
      );
      expect(find.text('GLASSES'), findsOneWidget);
    });

    testWidgets('About section is present', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 2400));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: SettingsScreen())),
      );
      await tester.pump();

      // Scroll down to find the About section
      await tester.dragUntilVisible(
        find.text('ABOUT'),
        find.byType(SingleChildScrollView),
        const Offset(0, -300),
      );
      expect(find.text('ABOUT'), findsOneWidget);
    });

    testWidgets('Active Provider spotlight is shown', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: SettingsScreen())),
      );
      await tester.pump();

      expect(find.text('Active Provider'), findsOneWidget);
    });

    testWidgets('Frontier Providers group is shown', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: SettingsScreen())),
      );
      await tester.pump();

      // May appear in both the spotlight card and group header
      expect(find.text('Frontier Providers'), findsWidgets);
    });
  });
}
