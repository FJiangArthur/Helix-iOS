import 'dart:async';
import 'dart:typed_data';
import '../../models/glasses_connection.dart';
import '../interfaces/i_ble_service.dart';
import '../ble.dart';
import '../../ble_manager.dart';

/// Production implementation of IBleService wrapping existing BleManager
class BleServiceImpl implements IBleService {
  final BleManager _bleManager;
  final _eventController = StreamController<BleEvent>.broadcast();
  final _connectionController = StreamController<GlassesConnection>.broadcast();

  GlassesConnection _currentConnection = GlassesConnection.disconnected();

  BleServiceImpl({BleManager? bleManager})
      : _bleManager = bleManager ?? BleManager.get() {
    _init();
  }

  void _init() {
    // Listen to BleManager status changes
    _bleManager.onStatusChanged = () {
      _updateConnectionState();
    };

    // Listen to BLE receive events and convert to BleEvent
    _bleManager.eventBleReceive.listen((bleReceive) {
      _handleBleReceive(bleReceive);
    });

    // Initialize connection state
    _updateConnectionState();
  }

  void _handleBleReceive(BleReceive bleReceive) {
    // Emit raw data
    // (dataStream is handled directly by BleManager.eventBleReceive)

    // Parse and emit events
    try {
      final cmd = bleReceive.getCmd();
      BleEvent? event;

      switch (cmd) {
        case 0x11: // Connection success
          event = BleEvent.glassesConnectSuccess;
          break;
        case 0x17: // EvenAI start
          event = BleEvent.evenaiStart;
          break;
        case 0x18: // EvenAI recording over
          event = BleEvent.evenaiRecordOver;
          break;
        case 0x19: // Up header (previous page)
          event = BleEvent.upHeader;
          break;
        case 0x1A: // Down header (next page)
          event = BleEvent.downHeader;
          break;
        case 0x1B: // Next page for EvenAI
          event = BleEvent.nextPageForEvenAI;
          break;
      }

      if (event != null) {
        _eventController.add(event);
      }
    } catch (e) {
      print('Error parsing BLE event: $e');
    }
  }

  void _updateConnectionState() {
    final isConnected = _bleManager.isConnected;

    if (isConnected && _bleManager.pairedGlasses.isNotEmpty) {
      final firstGlass = _bleManager.pairedGlasses.first;
      final deviceName = firstGlass['name'] ?? 'Unknown';

      _currentConnection = GlassesConnection.connected(
        deviceName: deviceName,
        // BleManager doesn't expose left/right IDs directly
        // These would need to be extracted from BleManager if available
      ).copyWith(
        // Default to excellent quality when connected
        quality: ConnectionQuality.excellent,
        lastSeen: DateTime.now(),
      );
    } else {
      _currentConnection = GlassesConnection.disconnected();
    }

    _connectionController.add(_currentConnection);
  }

  @override
  Stream<BleEvent> get eventStream => _eventController.stream;

  @override
  Stream<BleReceive> get dataStream => _bleManager.eventBleReceive;

  @override
  Stream<GlassesConnection> get connectionStream =>
      _connectionController.stream;

  @override
  GlassesConnection get currentConnection => _currentConnection;

  @override
  Future<void> startScan() async {
    await _bleManager.startScan();
  }

  @override
  Future<void> stopScan() async {
    await _bleManager.stopScan();
  }

  @override
  Future<bool> connectToGlasses(String deviceName) async {
    try {
      await _bleManager.connectToGlasses(deviceName);
      _updateConnectionState();
      return _bleManager.isConnected;
    } catch (e) {
      print('Error connecting to glasses: $e');
      return false;
    }
  }

  @override
  Future<void> disconnect() async {
    await _bleManager.disconnect();
    _updateConnectionState();
  }

  @override
  Future<bool> sendData(
    Uint8List data, {
    required String lr,
    int timeoutMs = 1000,
  }) async {
    try {
      await BleManager.sendData(data, lr: lr, timeoutMs: timeoutMs);
      return true;
    } catch (e) {
      print('Error sending data: $e');
      return false;
    }
  }

  @override
  Future<bool> sendBoth(
    Uint8List data, {
    int timeoutMs = 250,
  }) async {
    try {
      await BleManager.sendBoth(data, timeoutMs: timeoutMs);
      return true;
    } catch (e) {
      print('Error sending to both glasses: $e');
      return false;
    }
  }

  @override
  Future<BleReceive?> request(
    Uint8List data, {
    required String lr,
    int timeoutMs = 1000,
  }) async {
    try {
      final result = await BleManager.request(
        data,
        lr: lr,
        timeoutMs: timeoutMs,
      );
      return result;
    } catch (e) {
      print('Error in request: $e');
      return null;
    }
  }

  @override
  void startHeartbeat() {
    _bleManager.startSendBeatHeart();
  }

  @override
  void stopHeartbeat() {
    _bleManager.stopSendBeatHeart();
  }

  @override
  Future<int?> getBatteryLevel() async {
    // BleManager doesn't directly expose battery level
    // This would need to be queried via BLE commands
    // For now, return from connection state if available
    return _currentConnection.isConnected
        ? _currentConnection.batteryLevel
        : null;
  }

  @override
  void dispose() {
    _eventController.close();
    _connectionController.close();
  }
}
