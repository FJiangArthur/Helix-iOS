import 'dart:io';

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
  const pathProviderChannel = MethodChannel('plugins.flutter.io/path_provider');
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

  Future<void> pumpMainScreen(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(1000, 2000));
    addTearDown(() async {
      BleManager.get().stopSendBeatHeart();
      BleManager.get().onStatusChanged = null;
      ConversationEngine.instance.stop();
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      await tester.binding.setSurfaceSize(null);
    });

    await tester.pumpWidget(const MaterialApp(home: MainScreen()));
    await tester.pump();
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
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathProviderChannel, (call) async {
          final directory = Directory(
            '${Directory.systemTemp.path}/helix_tab_test_documents',
          )..createSync(recursive: true);
          return directory.path;
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
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathProviderChannel, null);
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
      ..answerAll = true
      ..autoShowFollowUps = true
      ..autoShowSummary = true
      ..preferredMicSource = 'glasses';
    await SettingsManager.instance.save();
  });

  group('MainScreen tab navigation', () {
    testWidgets('renders with 5 navigation destinations', (tester) async {
      await pumpMainScreen(tester);

      final navBar = find.byKey(const Key('main-navigation-bar'));
      expect(navBar, findsOneWidget);

      expect(find.byType(NavigationDestination), findsNWidgets(5));
    });

    testWidgets('tab labels match expected titles', (tester) async {
      await pumpMainScreen(tester);

      final destinations = tester.widgetList<NavigationDestination>(
        find.byType(NavigationDestination),
      );
      final labels = destinations.map((d) => d.label).toList();
      expect(labels, [
        'Assistant',
        'Device',
        'Sessions',
        'Knowledge',
        'Settings',
      ]);
    });

    testWidgets('tab icons are present for each destination', (tester) async {
      await pumpMainScreen(tester);

      // Tab 0 is selected (Assistant), so it shows chat_bubble_rounded.
      expect(find.byIcon(Icons.chat_bubble_rounded), findsOneWidget);
      expect(find.byIcon(Icons.bluetooth_rounded), findsOneWidget);
      expect(find.byIcon(Icons.graphic_eq_rounded), findsWidgets);
      expect(find.byIcon(Icons.lightbulb_outline_rounded), findsOneWidget);
      expect(find.byIcon(Icons.settings_outlined), findsOneWidget);
    });

    testWidgets('uses IndexedStack for state preservation', (tester) async {
      await pumpMainScreen(tester);

      expect(find.byType(IndexedStack), findsOneWidget);
    });

    testWidgets('Home tab (0) has no main AppBar on launch', (tester) async {
      await pumpMainScreen(tester);

      // Assistant is tab 0 (default), no main AppBar.
      final mainAppBars = tester.widgetList<AppBar>(find.byType(AppBar));
      final hasAssistantTitle = mainAppBars.any(
        (bar) => bar.title is Text && (bar.title as Text).data == 'Assistant',
      );
      expect(hasAssistantTitle, isFalse);
    });

    testWidgets('tapping Sessions tab shows Sessions sub-tabs', (tester) async {
      await pumpMainScreen(tester);

      final sessionsDest = find.byType(NavigationDestination).at(2);
      await tester.tap(sessionsDest);
      await tester.pumpAndSettle();

      expect(find.text('Monitor'), findsOneWidget);
      expect(find.text('Archive'), findsOneWidget);
      expect(find.text('Projects'), findsOneWidget);
    });

    testWidgets('tapping Knowledge tab shows Knowledge sub-tabs', (
      tester,
    ) async {
      await pumpMainScreen(tester);

      final knowledgeDest = find.byType(NavigationDestination).at(3);
      await tester.tap(knowledgeDest);
      await tester.pumpAndSettle();

      expect(find.text('Ask'), findsOneWidget);
      expect(find.text('Facts'), findsOneWidget);
      expect(find.text('Memories'), findsOneWidget);
      expect(find.text('Review'), findsOneWidget);
    });

    testWidgets('MainScreen.switchToTab loads migrated destinations', (
      tester,
    ) async {
      await pumpMainScreen(tester);

      MainScreen.switchToTab(2);
      await tester.pumpAndSettle();
      expect(find.text('Monitor'), findsOneWidget);

      MainScreen.switchToTab(3);
      await tester.pumpAndSettle();
      expect(find.text('Ask'), findsOneWidget);

      MainScreen.switchToTab(4);
      await tester.pumpAndSettle();
      expect(find.text('Settings'), findsWidgets);
    });

    testWidgets('navigation bar height is compact at 62', (tester) async {
      await pumpMainScreen(tester);

      final navBar = tester.widget<NavigationBar>(
        find.byKey(const Key('main-navigation-bar')),
      );
      expect(navBar.height, 62);
    });

    testWidgets('navigation bar shows only the selected label', (tester) async {
      await pumpMainScreen(tester);

      final navBar = tester.widget<NavigationBar>(
        find.byKey(const Key('main-navigation-bar')),
      );
      expect(
        navBar.labelBehavior,
        NavigationDestinationLabelBehavior.onlyShowSelected,
      );
    });

    testWidgets('settings gear icon remains available on Sessions tab', (
      tester,
    ) async {
      await pumpMainScreen(tester);

      final sessionsDest = find.byType(NavigationDestination).at(2);
      await tester.tap(sessionsDest);
      await tester.pumpAndSettle();

      expect(
        find.widgetWithIcon(IconButton, Icons.settings_outlined),
        findsOneWidget,
      );
    });
  });
}
