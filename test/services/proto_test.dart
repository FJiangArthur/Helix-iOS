import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_helix/services/ble.dart';
import 'package:flutter_helix/services/proto.dart';

void main() {
  group('Proto.sendHeartBeatForTest', () {
    test('succeeds when only the right lens is connected', () async {
      final requestedSides = <String>[];

      final result = await Proto.sendHeartBeatForTest(
        leftConnected: false,
        rightConnected: true,
        requestSide: (lr, data, timeoutMs) async {
          requestedSides.add(lr);
          final receive = BleReceive();
          receive.data = Uint8List.fromList([
            0x25,
            0x00,
            0x00,
            0x00,
            0x04,
            0x00,
          ]);
          return receive;
        },
      );

      expect(result, isTrue);
      expect(requestedSides, ['R']);
    });
  });

  group('Proto.exitForTest', () {
    test('succeeds when only the right lens is connected', () async {
      final requestedSides = <String>[];

      final result = await Proto.exitForTest(
        leftConnected: false,
        rightConnected: true,
        requestSide: (lr, data, timeoutMs) async {
          requestedSides.add(lr);
          final receive = BleReceive();
          receive.data = Uint8List.fromList([0x18, 0xc9]);
          return receive;
        },
      );

      expect(result, isTrue);
      expect(requestedSides, ['R']);
    });

    test('fails when a connected side does not acknowledge exit', () async {
      final result = await Proto.exitForTest(
        leftConnected: true,
        rightConnected: true,
        requestSide: (lr, data, timeoutMs) async {
          final receive = BleReceive();
          receive.data = Uint8List.fromList(
            lr == 'L' ? [0x18, 0xc9] : [0x18, 0x00],
          );
          return receive;
        },
      );

      expect(result, isFalse);
    });
  });

  group('Proto.hideDashboardForTest', () {
    test('sends the dashboard hide packet to connected sides', () async {
      final sent = <String, Uint8List>{};

      final result = await Proto.hideDashboardForTest(
        leftConnected: false,
        rightConnected: true,
        position: 3,
        sendSide: (lr, data) async {
          sent[lr] = data;
        },
      );

      expect(result, isTrue);
      expect(sent.keys, ['R']);
      expect(
        sent['R'],
        Uint8List.fromList([0x26, 0x07, 0x00, 0x01, 0x02, 0x00, 0x03]),
      );
    });
  });
}
