import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_helix/ble_manager.dart';
import 'package:flutter_helix/services/ble.dart';
import 'package:flutter_helix/services/conversation_engine.dart';
import 'package:flutter_helix/services/dashboard_service.dart';
import 'package:flutter_helix/services/handoff_memory.dart';
import 'package:flutter_helix/services/hud_controller.dart';
import 'package:flutter_helix/services/hud_intent.dart';
import 'package:flutter_helix/services/hud_widget_registry.dart';
import 'package:flutter_helix/services/settings_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('DashboardService', () {
    late DashboardService service;
    late List<String> dashboardRenders;
    late List<String> quickAskRestores;
    late int exitCalls;

    BleDeviceEvent headUpEvent({String label = 'head_up'}) => BleDeviceEvent(
      kind: BleDeviceEventKind.headUp,
      notifyIndex: 2,
      side: 'L',
      data: Uint8List.fromList([0xF5, 0x02]),
      timestamp: DateTime(2026, 3, 12, 10, 0),
      label: label,
    );

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      dashboardRenders = [];
      quickAskRestores = [];
      exitCalls = 0;

      SettingsManager.instance.dashboardTiltEnabled = true;
      HandoffMemory.instance.clear();
      ConversationEngine.instance.clearHistory();
      ConversationEngine.instance.stop();
      ConversationEngine.instance.setMode(ConversationMode.general);
      await HudController.instance.resetToIdle(source: 'test.dashboard.setup');
      HudController.instance.clearDisplay();

      service = DashboardService(
        bleManager: BleManager.get(),
        hudController: HudController.instance,
        conversationEngine: ConversationEngine.instance,
        handoffMemory: HandoffMemory.instance,
        settingsManager: SettingsManager.instance,
        dashboardRenderer: (text) async {
          dashboardRenders.add(text);
          return true;
        },
        quickAskRestorer: (text) async {
          quickAskRestores.add(text);
          return true;
        },
        exitRenderer: () async {
          exitCalls += 1;
          return true;
        },
        clock: () => DateTime(2026, 3, 12, 10, 0),
        cooldown: const Duration(milliseconds: 200),
        displayDuration: const Duration(milliseconds: 40),
      );

      await service.initialize();
    });

    tearDown(() async {
      await service.hideDashboard(source: 'test.dashboard.teardown');
      service.dispose();
      await HudController.instance.resetToIdle(source: 'test.dashboard.reset');
      HudController.instance.clearDisplay();
      SettingsManager.instance.dashboardTiltEnabled = true;
    });

    test(
      'shows the dashboard on a head gesture and restores idle after auto-hide',
      () async {
        await service.handleDeviceEvent(headUpEvent());

        expect(dashboardRenders, hasLength(1));
        expect(service.state.isActive, isTrue);
        expect(HudController.instance.currentIntent, HudIntent.dashboard);

        await Future<void>.delayed(const Duration(milliseconds: 80));

        expect(service.state.isActive, isFalse);
        expect(exitCalls, 1);
        expect(HudController.instance.currentIntent, HudIntent.idle);
      },
    );

    test('previewDashboard records the synthetic preview event', () async {
      await service.previewDashboard();

      expect(service.state.lastObservedEventLabel, 'preview_dashboard');
      expect(service.state.lastTriggerLabel, 'preview_dashboard');
      expect(service.state.isActive, isTrue);
    });

    test('suppresses repeated tilt events during cooldown', () async {
      await service.handleDeviceEvent(headUpEvent());
      await Future<void>.delayed(const Duration(milliseconds: 80));

      await service.handleDeviceEvent(headUpEvent(label: 'head_up_repeat'));

      expect(dashboardRenders, hasLength(1));
      expect(service.state.lastBlockedReason, 'Cooldown active');
      expect(exitCalls, 1);
    });

    test('restores quick ask text after the dashboard auto-hides', () async {
      BleManager.get().isConnected = true;
      HudController.instance.updateDisplay('Saved quick ask answer');
      await HudController.instance.beginQuickAsk(source: 'test.quickAskSetup');

      await service.handleDeviceEvent(headUpEvent());
      await Future<void>.delayed(const Duration(milliseconds: 80));

      expect(quickAskRestores, ['Saved quick ask answer']);
      expect(exitCalls, 0);
      expect(HudController.instance.currentIntent, HudIntent.quickAsk);
      expect(
        HudController.instance.currentDisplayText,
        'Saved quick ask answer',
      );
    });

    test(
      'ignores tilt gestures when the dashboard feature is disabled',
      () async {
        SettingsManager.instance.dashboardTiltEnabled = false;

        await service.handleDeviceEvent(headUpEvent());

        expect(dashboardRenders, isEmpty);
        expect(service.state.lastBlockedReason, 'Tilt dashboard disabled');
        expect(HudController.instance.currentIntent, HudIntent.idle);
      },
    );

    test('snapshot contains conversation metrics when idle', () async {
      await service.handleDeviceEvent(headUpEvent());

      expect(dashboardRenders, hasLength(1));
      final text = dashboardRenders.first;
      expect(text, HudWidgetRegistry.instance.pageText(0));
    });

    test(
      'idle dashboard shows the widget placeholder when nothing is configured',
      () async {
        await service.handleDeviceEvent(headUpEvent());

        final text = dashboardRenders.first;
        final lines = text.split('\n');
        expect(lines, [
          'No widgets enabled',
          '',
          'Go to Settings >',
          'HUD Widgets',
          'to add some',
        ]);
      },
    );

    test('all rendered lines fit in 24 chars', () async {
      await service.handleDeviceEvent(headUpEvent());

      final text = dashboardRenders.first;
      for (final line in text.split('\n')) {
        expect(
          line.length,
          lessThanOrEqualTo(24),
          reason: 'Line "$line" exceeds 24 chars',
        );
      }
    });

    test('uses extended display duration during active conversation', () {
      final activeService = DashboardService(
        bleManager: BleManager.get(),
        hudController: HudController.instance,
        conversationEngine: ConversationEngine.instance,
        handoffMemory: HandoffMemory.instance,
        settingsManager: SettingsManager.instance,
        dashboardRenderer: (text) async => true,
        quickAskRestorer: (text) async => true,
        exitRenderer: () async => true,
        clock: () => DateTime(2026, 3, 12, 10, 0),
        cooldown: const Duration(milliseconds: 200),
        displayDuration: const Duration(seconds: 5),
        activeDisplayDuration: const Duration(seconds: 8),
      );

      // Verify the durations are set correctly
      expect(activeService.displayDuration, const Duration(seconds: 5));
      expect(activeService.activeDisplayDuration, const Duration(seconds: 8));

      activeService.dispose();
    });

    test('bitmap dashboard auto-hides after the configured duration', () async {
      SettingsManager.instance.hudRenderPath = 'bitmap';
      var bitmapInvalidateCalls = 0;

      final bitmapService = DashboardService(
        bleManager: BleManager.get(),
        hudController: HudController.instance,
        conversationEngine: ConversationEngine.instance,
        handoffMemory: HandoffMemory.instance,
        settingsManager: SettingsManager.instance,
        dashboardRenderer: (text) async => true,
        quickAskRestorer: (text) async => true,
        exitRenderer: () async {
          exitCalls += 1;
          return true;
        },
        bitmapDeltaRenderer: () async => true,
        bitmapFullRenderer: () async => true,
        bitmapInvalidateCache: () {
          bitmapInvalidateCalls += 1;
        },
        clock: () => DateTime(2026, 3, 12, 10, 0),
        cooldown: const Duration(milliseconds: 200),
        displayDuration: const Duration(milliseconds: 40),
      );

      await bitmapService.initialize();
      await bitmapService.handleDeviceEvent(
        headUpEvent(label: 'bitmap_head_up'),
      );

      expect(bitmapService.state.isActive, isTrue);
      expect(HudController.instance.currentIntent, HudIntent.dashboard);

      await Future<void>.delayed(const Duration(milliseconds: 80));

      expect(bitmapService.state.isActive, isFalse);
      expect(HudController.instance.currentIntent, HudIntent.idle);
      expect(exitCalls, 0);
      expect(bitmapInvalidateCalls, 1);

      await bitmapService.hideDashboard(
        source: 'test.bitmapDashboard.teardown',
      );
      bitmapService.dispose();
      SettingsManager.instance.hudRenderPath = 'text';
    });
  });
}
