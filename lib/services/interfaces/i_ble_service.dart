import 'dart:async';
import 'dart:typed_data';
import '../../models/glasses_connection.dart';
import '../ble.dart';

/// Abstract interface for BLE communication with G1 glasses
/// This interface allows for mock implementations in tests
abstract class IBleService {
  /// Stream of BLE events from glasses
  Stream<BleEvent> get eventStream;

  /// Stream of raw BLE data received
  Stream<BleReceive> get dataStream;

  /// Current connection state
  Stream<GlassesConnection> get connectionStream;

  /// Get current connection state synchronously
  GlassesConnection get currentConnection;

  /// Start scanning for G1 glasses
  Future<void> startScan();

  /// Stop scanning
  Future<void> stopScan();

  /// Connect to specific glasses by device name
  Future<bool> connectToGlasses(String deviceName);

  /// Disconnect from glasses
  Future<void> disconnect();

  /// Send raw data to glasses with optional timeout
  Future<bool> sendData(
    Uint8List data, {
    required String lr, // "L" or "R" for left/right
    int timeoutMs = 1000,
  });

  /// Send data to both glasses
  Future<bool> sendBoth(
    Uint8List data, {
    int timeoutMs = 250,
  });

  /// Request/response pattern with timeout
  Future<BleReceive?> request(
    Uint8List data, {
    required String lr,
    int timeoutMs = 1000,
  });

  /// Start heartbeat to maintain connection
  void startHeartbeat();

  /// Stop heartbeat
  void stopHeartbeat();

  /// Get battery level (0-100)
  Future<int?> getBatteryLevel();

  /// Dispose resources
  void dispose();
}
