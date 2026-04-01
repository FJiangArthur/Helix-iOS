import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_helix/services/ble.dart';

void main() {
  group('BleTransportPolicy', () {
    test('retry count always includes the initial attempt', () {
      expect(BleTransportPolicy.attemptsForRetryCount(0), 1);
      expect(BleTransportPolicy.attemptsForRetryCount(1), 2);
      expect(BleTransportPolicy.attemptsForRetryCount(3), 4);
    });

    test('delivery only succeeds when every connected side succeeds', () {
      expect(
        BleTransportPolicy.didAllConnectedTargetsSucceed(
          leftConnected: true,
          rightConnected: true,
          leftSuccess: true,
          rightSuccess: true,
        ),
        isTrue,
      );

      expect(
        BleTransportPolicy.didAllConnectedTargetsSucceed(
          leftConnected: true,
          rightConnected: true,
          leftSuccess: true,
          rightSuccess: false,
        ),
        isFalse,
      );

      expect(
        BleTransportPolicy.didAllConnectedTargetsSucceed(
          leftConnected: true,
          rightConnected: false,
          leftSuccess: true,
          rightSuccess: false,
        ),
        isTrue,
      );

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
