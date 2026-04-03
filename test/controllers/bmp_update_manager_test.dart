import 'dart:typed_data';

import 'package:crclib/catalog.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_helix/controllers/bmp_update_manager.dart';
import 'package:flutter_helix/services/ble.dart';

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

    test(
      'updateBmp uses official Even bitmap packet format and command order',
      () async {
        final streamedPackets = <Uint8List>[];
        final requestPackets = <Uint8List>[];
        final bmpData = Uint8List.fromList(
          List<int>.generate(200, (index) => index & 0xff),
        );

        final result = await BmpUpdateManager.updateBmpForTest(
          'L',
          bmpData,
          sendSide: (lr, packet) async {
            streamedPackets.add(Uint8List.fromList(packet));
          },
          timeoutMs: 500,
          requestSide: (lr, packet, timeoutMs) async {
            requestPackets.add(Uint8List.fromList(packet));
            final receive = BleReceive();
            if (packet.first == 0x16) {
              receive.data = Uint8List.fromList([
                packet[0],
                packet[1],
                packet[2],
                packet[3],
                packet[4],
                0xc9,
              ]);
            } else {
              receive.data = Uint8List.fromList([packet.first, 0xc9]);
            }
            return receive;
          },
        );

        expect(result, isTrue);
        expect(streamedPackets, hasLength(2));
        expect(requestPackets, hasLength(2));

        expect(
          streamedPackets[0],
          Uint8List.fromList([
            0x15,
            0x00,
            0x00,
            0x1c,
            0x00,
            0x00,
            ...bmpData.sublist(0, 194),
          ]),
        );
        expect(
          streamedPackets[1],
          Uint8List.fromList([0x15, 0x01, ...bmpData.sublist(194)]),
        );
        expect(requestPackets[0], Uint8List.fromList([0x20, 0x0d, 0x0e]));

        final crcInput = Uint8List.fromList([
          0x00,
          0x1c,
          0x00,
          0x00,
          ...bmpData,
        ]);
        final checksum = Crc32Xz().convert(crcInput).toBigInt().toInt();
        expect(
          requestPackets[1],
          Uint8List.fromList([
            0x16,
            (checksum >> 24) & 0xff,
            (checksum >> 16) & 0xff,
            (checksum >> 8) & 0xff,
            checksum & 0xff,
          ]),
        );
      },
    );
  });
}
