import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_helix/services/ble.dart';

void main() {
  group('BleDeviceEvent', () {
    test('maps head-up and head-down device-order events', () {
      final headUpReceive = BleReceive.fromMap({
        'lr': 'L',
        'data': Uint8List.fromList([0xF5, 0x02]),
        'type': 'deviceOrder',
      });
      final headDownReceive = BleReceive.fromMap({
        'lr': 'R',
        'data': Uint8List.fromList([0xF5, 0x03]),
        'type': 'deviceOrder',
      });

      final headUpEvent = BleDeviceEvent.fromReceive(headUpReceive);
      final headDownEvent = BleDeviceEvent.fromReceive(headDownReceive);

      expect(headUpEvent, isNotNull);
      expect(headUpEvent!.kind, BleDeviceEventKind.headUp);
      expect(headUpEvent.isDashboardTrigger, isTrue);
      expect(headUpEvent.label, 'head_up');

      expect(headDownEvent, isNotNull);
      expect(headDownEvent!.kind, BleDeviceEventKind.headDown);
      expect(headDownEvent.isDashboardTrigger, isTrue);
      expect(headDownEvent.label, 'head_down');
    });

    test('keeps unknown device-order events discoverable', () {
      final receive = BleReceive.fromMap({
        'lr': 'L',
        'data': Uint8List.fromList([0xF5, 0x63, 0xAA]),
        'type': 'deviceOrder',
      });

      final event = BleDeviceEvent.fromReceive(receive);

      expect(event, isNotNull);
      expect(event!.kind, BleDeviceEventKind.unknownDeviceOrder);
      expect(event.notifyIndex, 0x63);
      expect(event.isKnown, isFalse);
      expect(event.label, 'unknown_device_order_99');
    });

    test('maps left touch (notifyIndex 1, side L) to pageBack', () {
      final receive = BleReceive.fromMap({
        'lr': 'L',
        'data': Uint8List.fromList([0xF5, 0x01]),
        'type': 'deviceOrder',
      });

      final event = BleDeviceEvent.fromReceive(receive);

      expect(event, isNotNull);
      expect(event!.kind, BleDeviceEventKind.pageBack);
      expect(event.side, 'L');
      expect(event.label, 'page_back');
    });

    test('maps right touch (notifyIndex 1, side R) to pageForward', () {
      final receive = BleReceive.fromMap({
        'lr': 'R',
        'data': Uint8List.fromList([0xF5, 0x01]),
        'type': 'deviceOrder',
      });

      final event = BleDeviceEvent.fromReceive(receive);

      expect(event, isNotNull);
      expect(event!.kind, BleDeviceEventKind.pageForward);
      expect(event.side, 'R');
      expect(event.label, 'page_forward');
    });

    test('maps evenai start event', () {
      final receive = BleReceive.fromMap({
        'lr': 'L',
        'data': Uint8List.fromList([0xF5, 23]),
        'type': 'deviceOrder',
      });

      final event = BleDeviceEvent.fromReceive(receive);

      expect(event, isNotNull);
      expect(event!.kind, BleDeviceEventKind.evenaiStart);
      expect(event.label, 'evenai_start');
    });

    test('maps evenai record over event', () {
      final receive = BleReceive.fromMap({
        'lr': 'R',
        'data': Uint8List.fromList([0xF5, 24]),
        'type': 'deviceOrder',
      });

      final event = BleDeviceEvent.fromReceive(receive);

      expect(event, isNotNull);
      expect(event!.kind, BleDeviceEventKind.evenaiRecordOver);
      expect(event.label, 'evenai_record_over');
    });

    test('maps exit function event', () {
      final receive = BleReceive.fromMap({
        'lr': 'L',
        'data': Uint8List.fromList([0xF5, 0x00]),
        'type': 'deviceOrder',
      });

      final event = BleDeviceEvent.fromReceive(receive);

      expect(event, isNotNull);
      expect(event!.kind, BleDeviceEventKind.exitFunc);
      expect(event.label, 'exit_function');
    });

    test('returns null for non-device-order command', () {
      final receive = BleReceive.fromMap({
        'lr': 'L',
        'data': Uint8List.fromList([0xF1, 0x01]),
        'type': 'data',
      });

      final event = BleDeviceEvent.fromReceive(receive);
      expect(event, isNull);
    });

    test('returns null for empty data', () {
      final receive = BleReceive.fromMap({
        'lr': 'L',
        'data': Uint8List(0),
        'type': 'deviceOrder',
      });

      final event = BleDeviceEvent.fromReceive(receive);
      expect(event, isNull);
    });

    test('isDashboardTrigger is false for non-head events', () {
      final receive = BleReceive.fromMap({
        'lr': 'L',
        'data': Uint8List.fromList([0xF5, 0x01]),
        'type': 'deviceOrder',
      });

      final event = BleDeviceEvent.fromReceive(receive);
      expect(event, isNotNull);
      expect(event!.isDashboardTrigger, isFalse);
    });

    test('glasses connect success event', () {
      final receive = BleReceive.fromMap({
        'lr': 'R',
        'data': Uint8List.fromList([0xF5, 17]),
        'type': 'deviceOrder',
      });

      final event = BleDeviceEvent.fromReceive(receive);

      expect(event, isNotNull);
      expect(event!.kind, BleDeviceEventKind.glassesConnectSuccess);
      expect(event.label, 'glasses_connect_success');
    });
  });

  group('BleDeviceEvent touch button context routing', () {
    // These tests verify that the BLE event mapping produces the correct
    // BleDeviceEventKind for left/right touches, which the EvenAI handler
    // then routes based on HudIntent context.

    test('left touch produces pageBack event for context-aware routing', () {
      // Left side touch -> pageBack -> EvenAI.handleLeftTouch()
      // During liveListening: triggers pause/resume
      // During quickAsk: triggers previousPage()
      final receive = BleReceive.fromMap({
        'lr': 'L',
        'data': Uint8List.fromList([0xF5, 0x01]),
        'type': 'deviceOrder',
      });
      final event = BleDeviceEvent.fromReceive(receive);

      expect(event, isNotNull);
      expect(event!.kind, BleDeviceEventKind.pageBack);
      expect(event.side, 'L');
    });

    test('right touch produces pageForward event for context-aware routing', () {
      // Right side touch -> pageForward -> EvenAI.handleRightTouch()
      // During liveListening: triggers manual question detection
      // During quickAsk: triggers nextPage()
      final receive = BleReceive.fromMap({
        'lr': 'R',
        'data': Uint8List.fromList([0xF5, 0x01]),
        'type': 'deviceOrder',
      });
      final event = BleDeviceEvent.fromReceive(receive);

      expect(event, isNotNull);
      expect(event!.kind, BleDeviceEventKind.pageForward);
      expect(event.side, 'R');
    });

    test('all touch event kinds are distinguishable for routing', () {
      // Verify the full set of event kinds that the context-aware handlers
      // use to decide behavior
      final kinds = BleDeviceEventKind.values;
      expect(kinds, contains(BleDeviceEventKind.pageBack));
      expect(kinds, contains(BleDeviceEventKind.pageForward));
      expect(kinds, contains(BleDeviceEventKind.headUp));
      expect(kinds, contains(BleDeviceEventKind.headDown));
      expect(kinds, contains(BleDeviceEventKind.exitFunc));
    });

    test('left touch during idle intent produces pageBack (no-op in handler)', () {
      // When HudIntent is idle, handleLeftTouch() does nothing,
      // but the BLE event still maps correctly to pageBack.
      final receive = BleReceive.fromMap({
        'lr': 'L',
        'data': Uint8List.fromList([0xF5, 0x01]),
        'type': 'deviceOrder',
      });
      final event = BleDeviceEvent.fromReceive(receive);

      expect(event, isNotNull);
      expect(event!.kind, BleDeviceEventKind.pageBack);
      expect(event.isDashboardTrigger, isFalse);
      expect(event.isKnown, isTrue);
    });

    test('right touch during idle intent produces pageForward (no-op in handler)', () {
      // When HudIntent is idle, handleRightTouch() does nothing,
      // but the BLE event still maps correctly to pageForward.
      final receive = BleReceive.fromMap({
        'lr': 'R',
        'data': Uint8List.fromList([0xF5, 0x01]),
        'type': 'deviceOrder',
      });
      final event = BleDeviceEvent.fromReceive(receive);

      expect(event, isNotNull);
      expect(event!.kind, BleDeviceEventKind.pageForward);
      expect(event.isDashboardTrigger, isFalse);
      expect(event.isKnown, isTrue);
    });

    test('head-up event is distinct from touch events for dashboard trigger', () {
      // Head-up triggers dashboard, not touch navigation.
      // This confirms the routing won't confuse head gestures with touches.
      final headUp = BleDeviceEvent.fromReceive(BleReceive.fromMap({
        'lr': 'L',
        'data': Uint8List.fromList([0xF5, 0x02]),
        'type': 'deviceOrder',
      }));
      final leftTouch = BleDeviceEvent.fromReceive(BleReceive.fromMap({
        'lr': 'L',
        'data': Uint8List.fromList([0xF5, 0x01]),
        'type': 'deviceOrder',
      }));

      expect(headUp!.kind, isNot(equals(leftTouch!.kind)));
      expect(headUp.isDashboardTrigger, isTrue);
      expect(leftTouch.isDashboardTrigger, isFalse);
    });

    test('exit function event is separate from touch navigation events', () {
      // Exit function (notifyIndex 0) should not be confused with
      // touch-based page navigation (notifyIndex 1).
      final exitEvent = BleDeviceEvent.fromReceive(BleReceive.fromMap({
        'lr': 'L',
        'data': Uint8List.fromList([0xF5, 0x00]),
        'type': 'deviceOrder',
      }));
      final touchEvent = BleDeviceEvent.fromReceive(BleReceive.fromMap({
        'lr': 'L',
        'data': Uint8List.fromList([0xF5, 0x01]),
        'type': 'deviceOrder',
      }));

      expect(exitEvent!.kind, BleDeviceEventKind.exitFunc);
      expect(touchEvent!.kind, BleDeviceEventKind.pageBack);
      expect(exitEvent.kind, isNot(equals(touchEvent.kind)));
    });

    test('touch side determines direction for same notifyIndex', () {
      // notifyIndex 1 on L side = pageBack, on R side = pageForward.
      // This is how the same physical gesture maps differently per side.
      final leftTouch = BleDeviceEvent.fromReceive(BleReceive.fromMap({
        'lr': 'L',
        'data': Uint8List.fromList([0xF5, 0x01]),
        'type': 'deviceOrder',
      }));
      final rightTouch = BleDeviceEvent.fromReceive(BleReceive.fromMap({
        'lr': 'R',
        'data': Uint8List.fromList([0xF5, 0x01]),
        'type': 'deviceOrder',
      }));

      expect(leftTouch!.kind, BleDeviceEventKind.pageBack);
      expect(rightTouch!.kind, BleDeviceEventKind.pageForward);
      expect(leftTouch.notifyIndex, equals(rightTouch.notifyIndex));
      expect(leftTouch.side, 'L');
      expect(rightTouch.side, 'R');
    });

    test('evenai events are not routable as touch events', () {
      // EvenAI start/recordOver should never be confused with touch nav.
      final evenaiStart = BleDeviceEvent.fromReceive(BleReceive.fromMap({
        'lr': 'L',
        'data': Uint8List.fromList([0xF5, 23]),
        'type': 'deviceOrder',
      }));
      final evenaiRecordOver = BleDeviceEvent.fromReceive(BleReceive.fromMap({
        'lr': 'R',
        'data': Uint8List.fromList([0xF5, 24]),
        'type': 'deviceOrder',
      }));

      expect(evenaiStart!.kind, BleDeviceEventKind.evenaiStart);
      expect(evenaiRecordOver!.kind, BleDeviceEventKind.evenaiRecordOver);
      expect(evenaiStart.kind, isNot(equals(BleDeviceEventKind.pageBack)));
      expect(evenaiStart.kind, isNot(equals(BleDeviceEventKind.pageForward)));
      expect(evenaiRecordOver.kind, isNot(equals(BleDeviceEventKind.pageBack)));
      expect(evenaiRecordOver.kind, isNot(equals(BleDeviceEventKind.pageForward)));
    });
  });
}
