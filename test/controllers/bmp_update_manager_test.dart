import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_helix/controllers/bmp_update_manager.dart';

void main() {
  group('BmpUpdateManager', () {
    test(
      'succeeds when only one lens is connected and sends only to that lens',
      () async {
        final sentSides = <String>[];
        var heartbeatStarted = false;

        final result = await BmpUpdateManager.sendConnectedSidesForTest(
          label: 'full send',
          leftConnected: true,
          rightConnected: false,
          heartbeatSender: () async => true,
          startHeartbeat: () {
            heartbeatStarted = true;
          },
          sendSide: (lr) async {
            sentSides.add(lr);
            return true;
          },
        );

        expect(result, isTrue);
        expect(heartbeatStarted, isTrue);
        expect(sentSides, ['L']);
      },
    );
  });
}
