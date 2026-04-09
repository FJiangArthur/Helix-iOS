import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_helix/ble_manager.dart';
import 'package:flutter_helix/services/ble.dart';
import 'package:flutter_helix/services/bitmap_hud/bitmap_hud_service.dart';
import 'package:flutter_helix/services/bitmap_hud/bmp_widget.dart';
import 'package:flutter_helix/services/bitmap_hud/display_constants.dart';
import 'package:flutter_helix/services/settings_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('BitmapHudService', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await SettingsManager.instance.initialize();
      SettingsManager.instance.hudRenderPath = 'bitmap';
      SettingsManager.instance.bitmapLayoutPreset = 'classic';
      BleManager.get().debugSetConnectionState(
        leftConnected: false,
        rightConnected: false,
      );
    });

    test(
      'pushDelta sends an update when refreshed content changes even without dirty flag',
      () async {
        final widget = _CounterWidget(incrementOnRefresh: true);
        final deltaCalls = <List<int>>[];

        final service = BitmapHudService.test(
          layout: _layout,
          zoneWidgets: {'clock': widget},
          lastSentBmp: Uint8List.fromList([0]),
          renderer: (_, zoneWidgets) async {
            final current = zoneWidgets['clock'] as _CounterWidget;
            return Uint8List.fromList([current.counter]);
          },
          deltaSender: (bmp, changed) async {
            deltaCalls.add(changed);
            return true;
          },
          fullSender: (_) async => true,
          isConnectedChecker: () => true,
        );

        final result = await service.pushDelta();

        expect(result, isTrue);
        expect(deltaCalls, hasLength(1));
        expect(deltaCalls.single, [0]);
      },
    );

    test(
      'pushFull clears widget dirty flags after a successful send',
      () async {
        final widget = _CounterWidget(incrementOnRefresh: false)
          ..isDirty = true;

        final service = BitmapHudService.test(
          layout: _layout,
          zoneWidgets: {'clock': widget},
          renderer: (_, zoneWidgets) async {
            final current = zoneWidgets['clock'] as _CounterWidget;
            return Uint8List.fromList([current.counter]);
          },
          fullSender: (_) async => true,
          deltaSender: (_, __) async => true,
          isConnectedChecker: () => true,
        );

        final result = await service.pushFull();

        expect(result, isTrue);
        expect(widget.isDirty, isFalse);
      },
    );

    test('pushFull proceeds when one lens is connected', () async {
      final widget = _CounterWidget(incrementOnRefresh: false);
      BleManager.get().debugSetConnectionState(
        leftConnected: true,
        rightConnected: false,
      );

      final service = BitmapHudService.test(
        layout: _layout,
        zoneWidgets: {'clock': widget},
        renderer: (_, zoneWidgets) async {
          final current = zoneWidgets['clock'] as _CounterWidget;
          return Uint8List.fromList([current.counter]);
        },
        fullSender: (_) async => true,
        deltaSender: (_, __) async => true,
      );

      final result = await service.pushFull();

      expect(result, isTrue);

      BleManager.get().debugSetConnectionState(
        leftConnected: false,
        rightConnected: false,
      );
    });

    test(
      'pushFull queues a second request while the first send is in flight',
      () async {
        final widget = _CounterWidget(incrementOnRefresh: false);
        final sendCompleters = [Completer<bool>(), Completer<bool>()];
        var sendCalls = 0;

        final service = BitmapHudService.test(
          layout: _layout,
          zoneWidgets: {'clock': widget},
          renderer: (_, zoneWidgets) async {
            final current = zoneWidgets['clock'] as _CounterWidget;
            return Uint8List.fromList([current.counter]);
          },
          fullSender: (_) async => sendCompleters[sendCalls++].future,
          deltaSender: (_, __) async => true,
          isConnectedChecker: () => true,
        );

        final first = service.pushFull();
        await Future<void>.delayed(Duration.zero);

        final second = service.pushFull();
        await Future<void>.delayed(Duration.zero);

        expect(sendCalls, 1);

        sendCompleters[0].complete(true);
        await Future<void>.delayed(Duration.zero);

        expect(sendCalls, 2);

        sendCompleters[1].complete(true);

        expect(await first, isTrue);
        expect(await second, isTrue);
      },
    );

    test(
      'reconnect does not auto-push while overlay is hidden',
      () async {
        var fullCalls = 0;
        final service = BitmapHudService.test(
          layout: _layout,
          zoneWidgets: {'clock': _CounterWidget(incrementOnRefresh: false)},
          fullSender: (_) async {
            fullCalls += 1;
            return true;
          },
          deltaSender: (_, __) async => true,
          isConnectedChecker: () => true,
          reconnectPushDelay: Duration.zero,
        );

        await service.handleConnectionStateForTest(BleConnectionState.connected);

        expect(fullCalls, 0);
        service.dispose();
      },
    );

    test(
      'resuming conversation only pushes delta when overlay is visible',
      () async {
        var deltaCalls = 0;
        final service = BitmapHudService.test(
          layout: _layout,
          zoneWidgets: {'clock': _CounterWidget(incrementOnRefresh: true)},
          lastSentBmp: Uint8List.fromList([0]),
          renderer: (_, zoneWidgets) async {
            final current = zoneWidgets['clock'] as _CounterWidget;
            return Uint8List.fromList([current.counter]);
          },
          fullSender: (_) async => true,
          deltaSender: (_, __) async {
            deltaCalls += 1;
            return true;
          },
          isConnectedChecker: () => true,
        );

        service.setConversationActive(true);
        service.setConversationActive(false);
        expect(deltaCalls, 0);

        service.setOverlayVisible(true);
        service.setConversationActive(true);
        // WS-D: setConversationActive(true) now force-clears the overlay
        // flag and invalidates the cached frame so the bitmap dashboard
        // cannot be resurrected during an active conversation.
        expect(service.isOverlayVisible, isFalse);
        service.setConversationActive(false);
        await Future<void>.delayed(Duration.zero);

        expect(deltaCalls, 0);
        service.dispose();
      },
    );

    // WS-D fix #2: setConversationActive(true) must clear _overlayVisible
    // and invalidate the cached frame, so the bitmap dashboard can never
    // be resurrected mid-conversation by a later reconnect or push.
    test(
      'WS-D: setConversationActive(true) clears overlay flag and cache',
      () async {
        var fullCalls = 0;
        final service = BitmapHudService.test(
          layout: _layout,
          zoneWidgets: {'clock': _CounterWidget(incrementOnRefresh: false)},
          lastSentBmp: Uint8List.fromList([1, 2, 3]),
          renderer: (_, __) async => Uint8List.fromList([0]),
          fullSender: (_) async {
            fullCalls += 1;
            return true;
          },
          deltaSender: (_, __) async => true,
          isConnectedChecker: () => true,
          overlayVisible: true,
          reconnectPushDelay: Duration.zero,
        );

        expect(service.isOverlayVisible, isTrue);
        service.setConversationActive(true);
        expect(service.isOverlayVisible, isFalse);
        expect(fullCalls, 0);
        service.dispose();
      },
    );

    // WS-D fix #1: post-reconnect pushFull must not fire during an active
    // conversation even when _overlayVisible is still true from stale
    // state. This repaints the bitmap dashboard on top of the
    // live-listening overlay and looks to the user like a factory reset.
    test(
      'WS-D: post-reconnect does not push while conversation is active',
      () async {
        var fullCalls = 0;
        final service = BitmapHudService.test(
          layout: _layout,
          zoneWidgets: {'clock': _CounterWidget(incrementOnRefresh: false)},
          renderer: (_, __) async => Uint8List.fromList([0]),
          fullSender: (_) async {
            fullCalls += 1;
            return true;
          },
          deltaSender: (_, __) async => true,
          isConnectedChecker: () => true,
          overlayVisible: true,
          reconnectPushDelay: Duration.zero,
        );

        // Mark conversation active (engine does this on start); the
        // overlay flag is still true from an earlier stale state.
        service.setConversationActive(true);
        await service.handleConnectionStateForTest(
          BleConnectionState.connected,
        );
        await Future<void>.delayed(Duration.zero);

        expect(fullCalls, 0);
        service.dispose();
      },
    );

    test(
      'layout changes while hidden defer the full push until the next show',
      () async {
        var fullCalls = 0;
        var deltaCalls = 0;
        final service = BitmapHudService.test(
          layout: _layout,
          zoneWidgets: {'clock': _CounterWidget(incrementOnRefresh: false)},
          lastSentBmp: Uint8List.fromList([7]),
          renderer: (_, __) async => Uint8List.fromList([7]),
          fullSender: (_) async {
            fullCalls += 1;
            return true;
          },
          deltaSender: (_, __) async {
            deltaCalls += 1;
            return true;
          },
          isConnectedChecker: () => true,
        );

        service.handleSettingsChangedForTest();
        expect(fullCalls, 0);
        expect(deltaCalls, 0);

        service.setOverlayVisible(true);
        final result = await service.pushDelta();

        expect(result, isTrue);
        expect(fullCalls, 1);
        expect(deltaCalls, 0);
        service.dispose();
      },
    );
  });
}

const _layout = HudLayout(
  id: 'test',
  name: 'Test',
  zones: [HudZone(id: 'clock', x: 0, y: 0, width: 10, height: 10)],
  defaultWidgetAssignments: {'clock': 'bmp_clock'},
);

class _CounterWidget extends BmpWidget {
  _CounterWidget({required this.incrementOnRefresh});

  final bool incrementOnRefresh;
  int counter = 0;

  @override
  String get id => 'bmp_clock';

  @override
  String get displayName => 'Clock';

  @override
  Duration get refreshInterval => Duration.zero;

  @override
  Future<void> refresh() async {
    if (incrementOnRefresh) {
      counter += 1;
    }
    lastRefreshed = DateTime.now();
  }

  @override
  void renderToCanvas(ui.Canvas canvas, HudZone zone) {}
}
