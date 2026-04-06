import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_helix/services/ble.dart';

void main() {
  group('BleTransportPolicy', () {
    test('retry count always includes the initial attempt', () {
      expect(BleTransportPolicy.attemptsForRetryCount(0), 1);
      expect(BleTransportPolicy.attemptsForRetryCount(1), 2);
      expect(BleTransportPolicy.attemptsForRetryCount(3), 4);
    });

    test('delivery succeeds when at least one connected side succeeds', () {
      // Both connected, both succeed
      expect(
        BleTransportPolicy.didAllConnectedTargetsSucceed(
          leftConnected: true,
          rightConnected: true,
          leftSuccess: true,
          rightSuccess: true,
        ),
        isTrue,
      );

      // Both connected, only L succeeds (R characteristic not ready)
      expect(
        BleTransportPolicy.didAllConnectedTargetsSucceed(
          leftConnected: true,
          rightConnected: true,
          leftSuccess: true,
          rightSuccess: false,
        ),
        isTrue,
      );

      // Both connected, only R succeeds
      expect(
        BleTransportPolicy.didAllConnectedTargetsSucceed(
          leftConnected: true,
          rightConnected: true,
          leftSuccess: false,
          rightSuccess: true,
        ),
        isTrue,
      );

      // Both connected, both fail
      expect(
        BleTransportPolicy.didAllConnectedTargetsSucceed(
          leftConnected: true,
          rightConnected: true,
          leftSuccess: false,
          rightSuccess: false,
        ),
        isFalse,
      );

      // Only L connected, L succeeds
      expect(
        BleTransportPolicy.didAllConnectedTargetsSucceed(
          leftConnected: true,
          rightConnected: false,
          leftSuccess: true,
          rightSuccess: false,
        ),
        isTrue,
      );

      // Neither connected
      expect(
        BleTransportPolicy.didAllConnectedTargetsSucceed(
          leftConnected: false,
          rightConnected: false,
          leftSuccess: false,
          rightSuccess: false,
        ),
        isFalse,
      );
    });
  });
}
