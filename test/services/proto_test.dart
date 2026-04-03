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
}
