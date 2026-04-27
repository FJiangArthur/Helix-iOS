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
      expect(labels, ['Home', 'Glasses', 'Live', 'Ask AI', 'Insights']);
    });

    testWidgets('tab icons are present for each destination', (tester) async {
      await pumpMainScreen(tester);

      // Tab 0 is selected (Home), so it shows chat_bubble_rounded
      expect(find.byIcon(Icons.chat_bubble_rounded), findsOneWidget);
      expect(find.byIcon(Icons.bluetooth_rounded), findsOneWidget);
      expect(find.byIcon(Icons.graphic_eq_rounded), findsWidgets);
      expect(find.byIcon(Icons.auto_awesome_outlined), findsOneWidget);
      expect(find.byIcon(Icons.lightbulb_outline_rounded), findsOneWidget);
    });

    testWidgets('uses IndexedStack for state preservation', (tester) async {
      await pumpMainScreen(tester);

      expect(find.byType(IndexedStack), findsOneWidget);
    });

    testWidgets('Home tab (0) has no main AppBar on launch', (tester) async {
      await pumpMainScreen(tester);

      // Home is tab 0 (default), no main AppBar — HomeScreen manages its own
      final mainAppBars = tester.widgetList<AppBar>(find.byType(AppBar));
      final hasHomeTitle = mainAppBars.any(
        (bar) => bar.title is Text && (bar.title as Text).data == 'Home',
      );
      expect(hasHomeTitle, isFalse);
    });

    testWidgets('tapping Live tab shows Live sub-tabs', (tester) async {
      await pumpMainScreen(tester);

      // Live is tab 2
      final liveDest = find.byType(NavigationDestination).at(2);
      await tester.tap(liveDest);
      await tester.pumpAndSettle();

      expect(find.text('Live'), findsWidgets);
      expect(find.text('History'), findsOneWidget);
    });

    testWidgets('tapping Ask AI tab shows Ask AI sub-tabs', (tester) async {
      await pumpMainScreen(tester);

      // Ask AI is tab 3
      final askAiDest = find.byType(NavigationDestination).at(3);
      await tester.tap(askAiDest);
      await tester.pumpAndSettle();

      expect(find.text('Daily AI'), findsOneWidget);
      expect(find.text('Review'), findsOneWidget);
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

    testWidgets('settings gear icon is in AppBar on Live tab', (tester) async {
      await pumpMainScreen(tester);

      // Switch to Live tab (2) which has its own AppBar with settings
      final liveDest = find.byType(NavigationDestination).at(2);
      await tester.tap(liveDest);
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.settings_outlined), findsOneWidget);
    });
  });
}
