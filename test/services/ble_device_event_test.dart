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
  });
}
