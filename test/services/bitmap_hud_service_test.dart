import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_helix/ble_manager.dart';
import 'package:flutter_helix/services/bitmap_hud/bitmap_hud_service.dart';
import 'package:flutter_helix/services/bitmap_hud/bmp_widget.dart';
import 'package:flutter_helix/services/bitmap_hud/display_constants.dart';

void main() {
  group('BitmapHudService', () {
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
      'clearDisplay sends a blank bitmap and keeps transport aligned',
      () async {
        final widget = _CounterWidget(incrementOnRefresh: false);
        final sentFrames = <Uint8List>[];

        final service = BitmapHudService.test(
          layout: _layout,
          zoneWidgets: {'clock': widget},
          lastSentBmp: Uint8List.fromList(
            List<int>.filled(G1Display.totalBmpSize, 0xff),
          ),
          renderer: (_, zoneWidgets) async {
            final current = zoneWidgets['clock'] as _CounterWidget;
            return Uint8List.fromList([current.counter]);
          },
          fullSender: (bmp) async {
            sentFrames.add(bmp);
            return true;
          },
          deltaSender: (bmp, changed) async {
            sentFrames.add(bmp);
            return true;
          },
          isConnectedChecker: () => true,
        );

        final result = await service.clearDisplay();

        expect(result, isTrue);
        expect(sentFrames, hasLength(1));
        expect(sentFrames.single.length, G1Display.totalBmpSize);
        expect(sentFrames.single[0], 0x42);
        expect(sentFrames.single[1], 0x4d);
        expect(sentFrames.single[G1Display.headerSize], 0x00);
        expect(
          sentFrames.single.sublist(54, 62),
          Uint8List.fromList([0xff, 0xff, 0xff, 0x00, 0x00, 0x00, 0x00, 0x00]),
        );
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
