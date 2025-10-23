import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_helix/services/implementations/mock_ble_service.dart';
import 'package:flutter_helix/models/glasses_connection.dart';
import 'package:flutter_helix/services/ble.dart';

void main() {
  late MockBleService service;

  setUp(() {
    service = MockBleService();
  });

  tearDown(() {
    service.dispose();
  });

  group('MockBleService Connection', () {
    test('starts in disconnected state', () {
      expect(service.currentConnection.isConnected, false);
      expect(
        service.currentConnection.quality,
        ConnectionQuality.disconnected,
      );
    });

    test('connects to glasses successfully', () async {
      final result = await service.connectToGlasses('G1-TEST-001');

      expect(result, true);
      expect(service.currentConnection.isConnected, true);
      expect(service.currentConnection.deviceName, 'G1-TEST-001');
      expect(service.currentConnection.quality, ConnectionQuality.excellent);
    });

    test('emits connection event on successful connection', () async {
      final eventsFuture = service.eventStream.first;

      await service.connectToGlasses('G1-TEST-001');

      final event = await eventsFuture;
      expect(event, BleEvent.glassesConnectSuccess);
    });

    test('connection stream emits state changes', () async {
      final states = <GlassesConnection>[];
      final subscription = service.connectionStream.listen(states.add);

      await service.connectToGlasses('G1-TEST-001');
      await Future.delayed(const Duration(milliseconds: 100));

      expect(states.length, greaterThan(0));
      expect(states.last.isConnected, true);

      await subscription.cancel();
    });

    test('fails connection when shouldFailConnection is true', () async {
      service.shouldFailConnection = true;

      final result = await service.connectToGlasses('G1-TEST-001');

      expect(result, false);
      expect(service.currentConnection.isConnected, false);
    });

    test('disconnects successfully', () async {
      await service.connectToGlasses('G1-TEST-001');
      expect(service.currentConnection.isConnected, true);

      await service.disconnect();

      expect(service.currentConnection.isConnected, false);
      expect(
        service.currentConnection.quality,
        ConnectionQuality.disconnected,
      );
    });
  });

  group('MockBleService Data Communication', () {
    setUp(() async {
      await service.connectToGlasses('G1-TEST-001');
    });

    test('sends data successfully', () async {
      final data = Uint8List.fromList([0x01, 0x02, 0x03]);

      final result = await service.sendData(data, lr: 'L');

      expect(result, true);
    });

    test('sendData emits data stream event', () async {
      final data = Uint8List.fromList([0x01, 0x02, 0x03]);
      final dataFuture = service.dataStream.first;

      await service.sendData(data, lr: 'L');

      final received = await dataFuture;
      expect(received.lr, 'L');
      expect(received.data, data);
    });

    test('fails send when shouldFailSend is true', () async {
      service.shouldFailSend = true;
      final data = Uint8List.fromList([0x01, 0x02, 0x03]);

      final result = await service.sendData(data, lr: 'L');

      expect(result, false);
    });

    test('sendBoth sends to both glasses', () async {
      final data = Uint8List.fromList([0x01, 0x02, 0x03]);
      final dataEvents = <BleReceive>[];
      final subscription = service.dataStream.listen(dataEvents.add);

      final result = await service.sendBoth(data);

      await Future.delayed(const Duration(milliseconds: 200));
      expect(result, true);
      expect(dataEvents.length, 2);
      expect(dataEvents.any((e) => e.lr == 'L'), true);
      expect(dataEvents.any((e) => e.lr == 'R'), true);

      await subscription.cancel();
    });

    test('request returns response', () async {
      final data = Uint8List.fromList([0x01, 0x02, 0x03]);

      final response = await service.request(data, lr: 'L');

      expect(response, isNotNull);
      expect(response!.lr, 'L');
      expect(response.type, 'response');
    });

    test('request returns null on failure', () async {
      service.shouldFailSend = true;
      final data = Uint8List.fromList([0x01, 0x02, 0x03]);

      final response = await service.request(data, lr: 'L');

      expect(response, isNull);
    });
  });

  group('MockBleService Heartbeat', () {
    setUp(() async {
      await service.connectToGlasses('G1-TEST-001');
    });

    test('startHeartbeat maintains connection', () async {
      service.startHeartbeat();

      await Future.delayed(const Duration(milliseconds: 500));

      expect(service.currentConnection.isConnected, true);

      service.stopHeartbeat();
    });

    test('stopHeartbeat stops periodic updates', () async {
      service.startHeartbeat();
      await Future.delayed(const Duration(milliseconds: 500));

      service.stopHeartbeat();

      // Should not crash or cause issues
      await Future.delayed(const Duration(milliseconds: 500));
      expect(service.currentConnection.isConnected, true);
    });
  });

  group('MockBleService Test Helpers', () {
    setUp(() async {
      await service.connectToGlasses('G1-TEST-001');
    });

    test('simulateDisconnection changes state to disconnected', () {
      expect(service.currentConnection.isConnected, true);

      service.simulateDisconnection();

      expect(service.currentConnection.isConnected, false);
    });

    test('simulateReconnection restores connection', () {
      service.simulateDisconnection();
      expect(service.currentConnection.isConnected, false);

      service.simulateReconnection();

      expect(service.currentConnection.isConnected, true);
    });

    test('simulatePoorQuality changes connection quality', () {
      expect(service.currentConnection.quality, ConnectionQuality.excellent);

      service.simulatePoorQuality();

      expect(service.currentConnection.quality, ConnectionQuality.poor);
    });

    test('setBatteryLevel updates battery state', () async {
      service.setBatteryLevel(42);

      await Future.delayed(const Duration(milliseconds: 50));

      final battery = await service.getBatteryLevel();
      expect(battery, 42);
    });

    test('simulateDataReceived emits data event', () async {
      final data = Uint8List.fromList([0xAA, 0xBB, 0xCC]);
      final dataFuture = service.dataStream.first;

      service.simulateDataReceived(data, 'R');

      final received = await dataFuture;
      expect(received.lr, 'R');
      expect(received.data, data);
    });

    test('simulateEvent emits custom BLE event', () async {
      final eventFuture = service.eventStream.first;

      service.simulateEvent(BleEvent.evenaiStart);

      final event = await eventFuture;
      expect(event, BleEvent.evenaiStart);
    });
  });

  group('MockBleService Battery Management', () {
    test('getBatteryLevel returns null when disconnected', () async {
      final battery = await service.getBatteryLevel();
      expect(battery, isNull);
    });

    test('getBatteryLevel returns level when connected', () async {
      await service.connectToGlasses('G1-TEST-001');

      final battery = await service.getBatteryLevel();

      expect(battery, isNotNull);
      expect(battery, greaterThanOrEqualTo(0));
      expect(battery, lessThanOrEqualTo(100));
    });

    test('setBatteryLevel clamps value to valid range', () async {
      await service.connectToGlasses('G1-TEST-001');

      service.setBatteryLevel(150); // Above max
      expect(await service.getBatteryLevel(), 100);

      service.setBatteryLevel(-10); // Below min
      expect(await service.getBatteryLevel(), 0);
    });
  });
}
