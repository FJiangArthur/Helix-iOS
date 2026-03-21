import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_helix/app.dart';
import 'package:flutter_helix/ble_manager.dart';
import 'package:flutter_helix/models/assistant_profile.dart';
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
    SharedPreferences.setMockInitialValues({'onboarding_complete': true});
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

  group('MainScreen tab navigation', () {
    testWidgets('renders with 5 navigation destinations', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: MainScreen()));
      await tester.pump();

      final navBar = find.byKey(const Key('main-navigation-bar'));
      expect(navBar, findsOneWidget);

      expect(find.byType(NavigationDestination), findsNWidgets(5));
    });

    testWidgets('tab labels match expected titles', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: MainScreen()));
      await tester.pump();

      // Labels are hidden (alwaysHide) but NavigationDestination still holds them
      final destinations = tester.widgetList<NavigationDestination>(
        find.byType(NavigationDestination),
      );
      final labels = destinations.map((d) => d.label).toList();
      expect(labels, ['Assistant', 'Glasses', 'History', 'Detail', 'Settings']);
    });

    testWidgets('tab icons are present for each destination', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: MainScreen()));
      await tester.pump();

      // Tab 0 is selected, so it shows the selectedIcon (chat_bubble_rounded)
      // Other tabs show their unselected icons
      expect(find.byIcon(Icons.chat_bubble_rounded), findsOneWidget);
      expect(find.byIcon(Icons.visibility_outlined), findsOneWidget);
      expect(find.byIcon(Icons.history), findsWidgets); // icon + selectedIcon same
      expect(find.byIcon(Icons.analytics_outlined), findsOneWidget);
      expect(find.byIcon(Icons.settings_outlined), findsOneWidget);
    });

    testWidgets('uses IndexedStack for state preservation', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: MainScreen()));
      await tester.pump();

      expect(find.byType(IndexedStack), findsOneWidget);
    });

    testWidgets('tapping Settings tab changes displayed screen', (
      tester,
    ) async {
      await tester.pumpWidget(const MaterialApp(home: MainScreen()));
      await tester.pump();

      // Tap the Settings destination (5th icon)
      await tester.tap(find.byIcon(Icons.settings_outlined));
      await tester.pumpAndSettle();

      // AppBar with 'Settings' title should appear (nav label also present
      // even when hidden, so we check for the AppBar specifically)
      expect(
        find.descendant(
          of: find.byType(AppBar),
          matching: find.text('Settings'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('tapping Glasses tab shows Glasses title', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: MainScreen()));
      await tester.pump();

      await tester.tap(find.byIcon(Icons.visibility_outlined));
      await tester.pumpAndSettle();

      expect(
        find.descendant(
          of: find.byType(AppBar),
          matching: find.text('Glasses'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('tapping History tab shows History title', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1600));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(const MaterialApp(home: MainScreen()));
      await tester.pump();

      // history icon is used for both icon and selectedIcon, find the
      // NavigationDestination widget area instead
      final historyDest = find.byType(NavigationDestination).at(2);
      await tester.tap(historyDest);
      await tester.pumpAndSettle();

      expect(
        find.descendant(
          of: find.byType(AppBar),
          matching: find.text('History'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('tapping Detail tab shows Detail title', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: MainScreen()));
      await tester.pump();

      // Detail tab is the 4th destination (index 3)
      final detailDest = find.byType(NavigationDestination).at(3);
      await tester.tap(detailDest);
      await tester.pumpAndSettle();

      expect(
        find.descendant(
          of: find.byType(AppBar),
          matching: find.text('Detail'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('Detail tab uses analytics icon', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: MainScreen()));
      await tester.pump();

      final destinations = tester.widgetList<NavigationDestination>(
        find.byType(NavigationDestination),
      );
      final detailDest = destinations.elementAt(3);
      expect(detailDest.label, 'Detail');

      // Verify the analytics icon is present
      expect(find.byIcon(Icons.analytics_outlined), findsOneWidget);
    });

    testWidgets('switching back to Assistant tab hides AppBar', (
      tester,
    ) async {
      await tester.pumpWidget(const MaterialApp(home: MainScreen()));
      await tester.pump();

      // Go to Settings
      await tester.tap(find.byIcon(Icons.settings_outlined));
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byType(AppBar),
          matching: find.text('Settings'),
        ),
        findsOneWidget,
      );

      // Go back to Assistant (now selected, so uses selectedIcon)
      await tester.tap(find.byIcon(Icons.chat_bubble_outline_rounded));
      await tester.pumpAndSettle();

      // Assistant tab has no AppBar
      expect(find.byType(AppBar), findsNothing);
      expect(find.text('Conversation Hub'), findsOneWidget);
    });

    testWidgets('navigation bar height is compact at 56', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: MainScreen()));
      await tester.pump();

      final navBar = tester.widget<NavigationBar>(
        find.byKey(const Key('main-navigation-bar')),
      );
      expect(navBar.height, 56);
    });

    testWidgets('navigation bar hides labels', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: MainScreen()));
      await tester.pump();

      final navBar = tester.widget<NavigationBar>(
        find.byKey(const Key('main-navigation-bar')),
      );
      expect(
        navBar.labelBehavior,
        NavigationDestinationLabelBehavior.alwaysHide,
      );
    });
  });
}
