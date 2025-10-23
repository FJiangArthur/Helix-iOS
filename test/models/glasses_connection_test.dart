import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_helix/models/glasses_connection.dart';

void main() {
  group('GlassesConnection', () {
    test('disconnected factory creates correct state', () {
      final connection = GlassesConnection.disconnected();

      expect(connection.isConnected, false);
      expect(connection.quality, ConnectionQuality.disconnected);
      expect(connection.deviceName, null);
      expect(connection.batteryLevel, 0);
    });

    test('connected factory creates correct state', () {
      final connection = GlassesConnection.connected(
        deviceName: 'G1-TEST',
        leftGlassId: 'LEFT-123',
        rightGlassId: 'RIGHT-456',
      );

      expect(connection.isConnected, true);
      expect(connection.deviceName, 'G1-TEST');
      expect(connection.leftGlassId, 'LEFT-123');
      expect(connection.rightGlassId, 'RIGHT-456');
      expect(connection.quality, ConnectionQuality.excellent);
      expect(connection.connectedAt, isNotNull);
      expect(connection.lastSeen, isNotNull);
    });

    test('serializes to JSON correctly', () {
      final connection = GlassesConnection.connected(
        deviceName: 'G1-TEST',
      );

      final json = connection.toJson();

      expect(json['isConnected'], true);
      expect(json['deviceName'], 'G1-TEST');
      expect(json['quality'], 'excellent');
    });

    test('deserializes from JSON correctly', () {
      final json = {
        'isConnected': true,
        'deviceName': 'G1-TEST',
        'leftGlassId': 'LEFT-123',
        'batteryLevel': 85,
        'quality': 'good',
      };

      final connection = GlassesConnection.fromJson(json);

      expect(connection.isConnected, true);
      expect(connection.deviceName, 'G1-TEST');
      expect(connection.leftGlassId, 'LEFT-123');
      expect(connection.batteryLevel, 85);
      expect(connection.quality, ConnectionQuality.good);
    });

    test('copyWith creates modified copy', () {
      final original = GlassesConnection.disconnected();
      final updated = original.copyWith(
        isConnected: true,
        deviceName: 'G1-NEW',
        batteryLevel: 75,
      );

      expect(original.isConnected, false);
      expect(updated.isConnected, true);
      expect(updated.deviceName, 'G1-NEW');
      expect(updated.batteryLevel, 75);
    });
  });
}
