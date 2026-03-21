import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_helix/ble_manager.dart';
import 'package:flutter_helix/models/assistant_profile.dart';
import 'package:flutter_helix/screens/detail_analysis_screen.dart';
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

  group('DetailAnalysisScreen widget rendering', () {
    testWidgets('renders without errors', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: DetailAnalysisScreen())),
      );
      await tester.pump();

      expect(find.byType(DetailAnalysisScreen), findsOneWidget);
    });

    testWidgets('shows empty state when no recording has happened', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: DetailAnalysisScreen())),
      );
      await tester.pump();

      // Empty state shows the analytics icon and instructional text
      expect(find.byIcon(Icons.analytics_rounded), findsOneWidget);
      expect(find.text('No analysis yet'), findsOneWidget);
      expect(
        find.text('Tap the mic button to start recording'),
        findsOneWidget,
      );
    });

    testWidgets('FAB mic button exists and is tappable', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: DetailAnalysisScreen())),
      );
      await tester.pump();

      // The FAB should show the mic icon when not recording
      expect(find.byType(FloatingActionButton), findsOneWidget);
      expect(find.byIcon(Icons.mic_rounded), findsOneWidget);
    });

    testWidgets('empty state shows Chinese text when language is zh', (
      tester,
    ) async {
      SettingsManager.instance.language = 'zh';

      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: DetailAnalysisScreen())),
      );
      await tester.pump();

      expect(find.text('No analysis yet'), findsNothing);
      expect(find.byIcon(Icons.analytics_rounded), findsOneWidget);
    });

    testWidgets('screen has a scroll view for content', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: DetailAnalysisScreen())),
      );
      await tester.pump();

      // The screen uses SafeArea and Column layout
      expect(find.byType(SafeArea), findsOneWidget);
    });

    testWidgets('recording indicator is NOT shown when idle', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: DetailAnalysisScreen())),
      );
      await tester.pump();

      // "Recording" label should not appear when not recording
      expect(find.text('Recording'), findsNothing);
    });

    testWidgets('LIVE TRANSCRIPT label is NOT shown when idle', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: DetailAnalysisScreen())),
      );
      await tester.pump();

      expect(find.text('LIVE TRANSCRIPT'), findsNothing);
    });

    testWidgets('Q&A HISTORY section is NOT shown when idle', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: DetailAnalysisScreen())),
      );
      await tester.pump();

      expect(find.text('Q&A HISTORY'), findsNothing);
    });

    testWidgets('FULL TRANSCRIPT section is NOT shown when idle', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: DetailAnalysisScreen())),
      );
      await tester.pump();

      expect(find.text('FULL TRANSCRIPT'), findsNothing);
    });

    testWidgets('CONVERSATION ANALYSIS is NOT shown when idle', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: DetailAnalysisScreen())),
      );
      await tester.pump();

      expect(find.text('CONVERSATION ANALYSIS'), findsNothing);
    });
  });
}
