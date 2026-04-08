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

    test('still succeeds when one connected side acknowledges exit', () async {
      // Per BleTransportPolicy: at-least-one-side success is sufficient
      // because the glasses internally relay between L and R.
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

      expect(result, isTrue);
    });

    test('fails when both connected sides reject exit', () async {
      final result = await Proto.exitForTest(
        leftConnected: true,
        rightConnected: true,
        requestSide: (lr, data, timeoutMs) async {
          final receive = BleReceive();
          receive.data = Uint8List.fromList([0x18, 0x00]);
          return receive;
        },
      );

      expect(result, isFalse);
    });
  });

  group('Proto.pushScreenToConnectedSidesForTest', () {
    BleReceive ack() {
      final r = BleReceive();
      r.data = Uint8List.fromList([0xf4, 0xc9]);
      return r;
    }

    BleReceive nack() {
      final r = BleReceive();
      r.data = Uint8List.fromList([0xf4, 0x00]);
      return r;
    }

    BleReceive timeout() {
      final r = BleReceive();
      r.isTimeout = true;
      return r;
    }

    test('sends to both sides independently when both connected', () async {
      final sides = <String>[];

      final result = await Proto.pushScreenToConnectedSidesForTest(
        screenId: 0x00,
        leftConnected: true,
        rightConnected: true,
        requestSide: (lr, data, timeoutMs) async {
          sides.add(lr);
          return ack();
        },
      );

      expect(result, isTrue);
      expect(sides, ['L', 'R']);
    });

    test('R still gets command when L times out', () async {
      final sides = <String>[];

      final result = await Proto.pushScreenToConnectedSidesForTest(
        screenId: 0x00,
        leftConnected: true,
        rightConnected: true,
        requestSide: (lr, data, timeoutMs) async {
          sides.add(lr);
          return lr == 'L' ? timeout() : ack();
        },
      );

      // Both sides were attempted
      expect(sides, ['L', 'R']);
      // Per BleTransportPolicy: a single-side success is sufficient because
      // the glasses internally relay between L and R.
      expect(result, isTrue);
    });

    test('succeeds when only R is connected', () async {
      final sides = <String>[];

      final result = await Proto.pushScreenToConnectedSidesForTest(
        screenId: 0x01,
        leftConnected: false,
        rightConnected: true,
        requestSide: (lr, data, timeoutMs) async {
          sides.add(lr);
          return ack();
        },
      );

      expect(result, isTrue);
      expect(sides, ['R']);
    });

    test('fails when connected side returns nack', () async {
      final result = await Proto.pushScreenToConnectedSidesForTest(
        screenId: 0x00,
        leftConnected: true,
        rightConnected: false,
        requestSide: (lr, data, timeoutMs) async => nack(),
      );

      expect(result, isFalse);
    });

    test('returns false when no sides are connected', () async {
      final result = await Proto.pushScreenToConnectedSidesForTest(
        screenId: 0x00,
        leftConnected: false,
        rightConnected: false,
        requestSide: (lr, data, timeoutMs) async => ack(),
      );

      expect(result, isFalse);
    });
  });

  group('Proto.sendEvenAIData (M3 inter-side delay)', () {
    test('inserts >=400 ms between L and R writes when both connected',
        () async {
      final calls = <(String, int)>[];
      final start = DateTime.now();

      final ok = await Proto.sendEvenAIDataForTest(
        dataList: [
          Uint8List.fromList([0x4E, 0, 1, 0, 0x71, 0, 0, 1, 1]),
        ],
        leftConnected: true,
        rightConnected: true,
        requestSide: (_, lr, __) async {
          calls.add((lr, DateTime.now().difference(start).inMilliseconds));
          return true;
        },
      );

      expect(ok, isTrue);
      expect(calls.length, 2);
      expect(calls[0].$1, 'L');
      expect(calls[1].$1, 'R');
      // L→R delta must be >=400 ms (Proto.evenAIInterSideDelay).
      final delta = calls[1].$2 - calls[0].$2;
      expect(delta, greaterThanOrEqualTo(400));
    });

    test('only-L connected sends once with no delay gate', () async {
      final calls = <String>[];
      final stopwatch = Stopwatch()..start();

      final ok = await Proto.sendEvenAIDataForTest(
        dataList: [
          Uint8List.fromList([0x4E, 0, 1, 0, 0x71, 0, 0, 1, 1]),
        ],
        leftConnected: true,
        rightConnected: false,
        requestSide: (_, lr, __) async {
          calls.add(lr);
          return true;
        },
      );
      stopwatch.stop();

      expect(ok, isTrue);
      expect(calls, ['L']);
      // No 400 ms wait should happen when only L is connected.
      expect(stopwatch.elapsedMilliseconds, lessThan(200));
    });

    test('only-R connected sends once with no delay gate', () async {
      final calls = <String>[];
      final stopwatch = Stopwatch()..start();

      final ok = await Proto.sendEvenAIDataForTest(
        dataList: [
          Uint8List.fromList([0x4E, 0, 1, 0, 0x71, 0, 0, 1, 1]),
        ],
        leftConnected: false,
        rightConnected: true,
        requestSide: (_, lr, __) async {
          calls.add(lr);
          return true;
        },
      );
      stopwatch.stop();

      expect(ok, isTrue);
      expect(calls, ['R']);
      expect(stopwatch.elapsedMilliseconds, lessThan(200));
    });

    test('inter-side delay constant matches consolidated protocol §5', () {
      expect(Proto.evenAIInterSideDelay, const Duration(milliseconds: 400));
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

    test('paces dashboard hide sends across both connected sides', () async {
      final calls = <({String side, int elapsedMs})>[];
      final stopwatch = Stopwatch()..start();

      final result = await Proto.hideDashboardForTest(
        leftConnected: true,
        rightConnected: true,
        interSideDelay: const Duration(milliseconds: 25),
        sendSide: (lr, data) async {
          calls.add((side: lr, elapsedMs: stopwatch.elapsedMilliseconds));
        },
      );

      expect(result, isTrue);
      expect(calls.map((call) => call.side).toList(), ['L', 'R']);
      expect(calls[1].elapsedMs - calls[0].elapsedMs, greaterThanOrEqualTo(25));
    });
  });
}
