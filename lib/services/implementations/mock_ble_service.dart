import 'dart:async';
import 'dart:typed_data';
import '../../models/glasses_connection.dart';
import '../ble.dart';
import '../interfaces/i_ble_service.dart';

/// Mock BLE service for testing without physical glasses
/// Simulates BLE events and connection states
class MockBleService implements IBleService {
  final _eventController = StreamController<BleEvent>.broadcast();
  final _dataController = StreamController<BleReceive>.broadcast();
  final _connectionController = StreamController<GlassesConnection>.broadcast();

  GlassesConnection _currentConnection = GlassesConnection.disconnected();
  Timer? _heartbeatTimer;
  bool _isScanning = false;
  int _batteryLevel = 85;

  // Configurable delays for realistic simulation
  Duration connectDelay = const Duration(milliseconds: 500);
  Duration sendDelay = const Duration(milliseconds: 50);

  // Test control flags
  bool shouldFailConnection = false;
  bool shouldFailSend = false;
  int sendFailureCount = 0;

  @override
  Stream<BleEvent> get eventStream => _eventController.stream;

  @override
  Stream<BleReceive> get dataStream => _dataController.stream;

  @override
  Stream<GlassesConnection> get connectionStream =>
      _connectionController.stream;

  @override
  GlassesConnection get currentConnection => _currentConnection;

  @override
  Future<void> startScan() async {
    _isScanning = true;
    await Future.delayed(const Duration(milliseconds: 100));

    // Simulate finding glasses
    final mockGlasses = [
      'G1-TEST-001',
      'G1-TEST-002',
    ];

    for (final device in mockGlasses) {
      await Future.delayed(const Duration(milliseconds: 200));
      // Could add a discovered devices stream if needed
    }
  }

  @override
  Future<void> stopScan() async {
    _isScanning = false;
    await Future.delayed(const Duration(milliseconds: 50));
  }

  @override
  Future<bool> connectToGlasses(String deviceName) async {
    await Future.delayed(connectDelay);

    if (shouldFailConnection) {
      _updateConnection(GlassesConnection.disconnected());
      return false;
    }

    _currentConnection = GlassesConnection.connected(
      deviceName: deviceName,
      leftGlassId: 'LEFT-${deviceName}',
      rightGlassId: 'RIGHT-${deviceName}',
    ).copyWith(batteryLevel: _batteryLevel);

    _updateConnection(_currentConnection);
    _eventController.add(BleEvent.glassesConnectSuccess);

    return true;
  }

  @override
  Future<void> disconnect() async {
    await Future.delayed(const Duration(milliseconds: 100));

    _currentConnection = GlassesConnection.disconnected();
    _updateConnection(_currentConnection);

    stopHeartbeat();
  }

  @override
  Future<bool> sendData(
    Uint8List data, {
    required String lr,
    int timeoutMs = 1000,
  }) async {
    await Future.delayed(sendDelay);

    if (shouldFailSend || sendFailureCount > 0) {
      if (sendFailureCount > 0) sendFailureCount--;
      return false;
    }

    // Simulate successful send
    _dataController.add(BleReceive()
      ..lr = lr
      ..data = data
      ..type = 'send_ack');

    return true;
  }

  @override
  Future<bool> sendBoth(
    Uint8List data, {
    int timeoutMs = 250,
  }) async {
    final leftResult = await sendData(data, lr: 'L', timeoutMs: timeoutMs);
    final rightResult = await sendData(data, lr: 'R', timeoutMs: timeoutMs);

    return leftResult && rightResult;
  }

  @override
  Future<BleReceive?> request(
    Uint8List data, {
    required String lr,
    int timeoutMs = 1000,
  }) async {
    final success = await sendData(data, lr: lr, timeoutMs: timeoutMs);

    if (!success) return null;

    // Simulate response
    await Future.delayed(Duration(milliseconds: timeoutMs ~/ 2));

    return BleReceive()
      ..lr = lr
      ..data = Uint8List.fromList([0x01, 0x02, 0x03])
      ..type = 'response';
  }

  @override
  void startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(
      const Duration(seconds: 2),
      (_) {
        if (_currentConnection.isConnected) {
          // Simulate battery drain
          if (_batteryLevel > 0 && DateTime.now().second % 10 == 0) {
            _batteryLevel--;
            _currentConnection =
                _currentConnection.copyWith(batteryLevel: _batteryLevel);
            _updateConnection(_currentConnection);
          }
        }
      },
    );
  }

  @override
  void stopHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
  }

  @override
  Future<int?> getBatteryLevel() async {
    await Future.delayed(const Duration(milliseconds: 100));
    return _currentConnection.isConnected ? _batteryLevel : null;
  }

  @override
  void dispose() {
    _eventController.close();
    _dataController.close();
    _connectionController.close();
    stopHeartbeat();
  }

  // Test helper methods

  /// Simulate connection lost
  void simulateDisconnection() {
    _currentConnection = GlassesConnection.disconnected();
    _updateConnection(_currentConnection);
  }

  /// Simulate reconnection
  void simulateReconnection() {
    if (_currentConnection.deviceName != null) {
      _currentConnection = _currentConnection.copyWith(
        isConnected: true,
        quality: ConnectionQuality.excellent,
      );
      _updateConnection(_currentConnection);
      _eventController.add(BleEvent.glassesConnectSuccess);
    }
  }

  /// Simulate poor connection quality
  void simulatePoorQuality() {
    _currentConnection =
        _currentConnection.copyWith(quality: ConnectionQuality.poor);
    _updateConnection(_currentConnection);
  }

  /// Simulate battery level change
  void setBatteryLevel(int level) {
    _batteryLevel = level.clamp(0, 100);
    _currentConnection = _currentConnection.copyWith(batteryLevel: _batteryLevel);
    _updateConnection(_currentConnection);
  }

  /// Simulate receiving data from glasses
  void simulateDataReceived(Uint8List data, String lr) {
    _dataController.add(BleReceive()
      ..lr = lr
      ..data = data
      ..type = 'received');
  }

  /// Simulate BLE event
  void simulateEvent(BleEvent event) {
    _eventController.add(event);
  }

  void _updateConnection(GlassesConnection connection) {
    _currentConnection = connection;
    _connectionController.add(connection);
  }
}
