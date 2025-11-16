/// BLE (Bluetooth Low Energy) Test Fixtures
///
/// Provides factory methods and fixtures for creating test BLE data

import 'dart:typed_data';
import 'package:flutter_helix/models/ble_transaction.dart';

/// Factory for creating test BLE transactions
class BLETransactionFactory {
  /// Create a basic BLE transaction
  static BLETransaction create({
    Uint8List? data,
    DateTime? timestamp,
    BLETransactionType type = BLETransactionType.write,
    String? deviceId,
  }) {
    return BLETransaction(
      data: data ?? Uint8List.fromList(<int>[0x01, 0x02, 0x03]),
      timestamp: timestamp ?? DateTime.now(),
      type: type,
      deviceId: deviceId ?? 'test-device-001',
    );
  }

  /// Create a write transaction
  static BLETransaction createWrite({
    required Uint8List data,
    String? deviceId,
  }) {
    return create(
      data: data,
      type: BLETransactionType.write,
      deviceId: deviceId,
    );
  }

  /// Create a read transaction
  static BLETransaction createRead({
    required Uint8List data,
    String? deviceId,
  }) {
    return create(
      data: data,
      type: BLETransactionType.read,
      deviceId: deviceId,
    );
  }

  /// Create a list of transactions
  static List<BLETransaction> createList({
    required int count,
    BLETransactionType type = BLETransactionType.write,
    String? deviceId,
  }) {
    final List<BLETransaction> transactions = <BLETransaction>[];

    for (int i = 0; i < count; i++) {
      transactions.add(
        create(
          data: Uint8List.fromList(<int>[i % 256]),
          type: type,
          deviceId: deviceId,
        ),
      );
    }

    return transactions;
  }

  /// Create audio data transaction
  static BLETransaction createAudioData({
    required Uint8List audioData,
    String? deviceId,
  }) {
    return create(
      data: audioData,
      type: BLETransactionType.write,
      deviceId: deviceId ?? 'glasses-audio-001',
    );
  }

  /// Create control command transaction
  static BLETransaction createControlCommand({
    required int command,
    String? deviceId,
  }) {
    return create(
      data: Uint8List.fromList(<int>[command]),
      type: BLETransactionType.write,
      deviceId: deviceId,
    );
  }
}

/// BLE test constants
class BLETestConstants {
  static const String testDeviceId = 'test-glasses-001';
  static const String testDeviceName = 'Test Even Glasses';

  // Common BLE commands
  static const int commandStart = 0x01;
  static const int commandStop = 0x02;
  static const int commandPause = 0x03;
  static const int commandResume = 0x04;

  // Test UUIDs
  static const String serviceUUID = '12345678-1234-1234-1234-123456789012';
  static const String characteristicUUID = '87654321-4321-4321-4321-210987654321';

  // Data sizes
  static const int smallPacketSize = 20;
  static const int mediumPacketSize = 100;
  static const int largePacketSize = 512;
}

/// Mock BLE device builder
class MockBLEDeviceBuilder {
  MockBLEDeviceBuilder() {
    _deviceId = BLETestConstants.testDeviceId;
    _deviceName = BLETestConstants.testDeviceName;
    _isConnected = false;
    _batteryLevel = 100;
    _signalStrength = -50;
  }

  late String _deviceId;
  late String _deviceName;
  late bool _isConnected;
  late int _batteryLevel;
  late int _signalStrength;

  /// Set device ID
  MockBLEDeviceBuilder withDeviceId(String id) {
    _deviceId = id;
    return this;
  }

  /// Set device name
  MockBLEDeviceBuilder withDeviceName(String name) {
    _deviceName = name;
    return this;
  }

  /// Set connected state
  MockBLEDeviceBuilder connected() {
    _isConnected = true;
    return this;
  }

  /// Set disconnected state
  MockBLEDeviceBuilder disconnected() {
    _isConnected = false;
    return this;
  }

  /// Set battery level
  MockBLEDeviceBuilder withBatteryLevel(int level) {
    _batteryLevel = level;
    return this;
  }

  /// Set signal strength
  MockBLEDeviceBuilder withSignalStrength(int strength) {
    _signalStrength = strength;
    return this;
  }

  /// Build device data
  Map<String, dynamic> build() {
    return <String, dynamic>{
      'deviceId': _deviceId,
      'deviceName': _deviceName,
      'isConnected': _isConnected,
      'batteryLevel': _batteryLevel,
      'signalStrength': _signalStrength,
    };
  }
}

/// BLE test data
class BLETestData {
  /// Sample device IDs
  static const List<String> deviceIds = <String>[
    'glasses-001',
    'glasses-002',
    'glasses-003',
  ];

  /// Sample device names
  static const List<String> deviceNames = <String>[
    'Even Glasses #1',
    'Even Glasses #2',
    'Even Glasses #3',
  ];

  /// Battery levels for testing
  static const List<int> batteryLevels = <int>[
    100, // Full
    75,  // Good
    50,  // Medium
    25,  // Low
    10,  // Critical
  ];

  /// Signal strengths (RSSI values)
  static const List<int> signalStrengths = <int>[
    -30, // Excellent
    -50, // Good
    -70, // Fair
    -90, // Poor
  ];
}
