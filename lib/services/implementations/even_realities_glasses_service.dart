// ABOUTME: Even Realities specific glasses service implementation
// ABOUTME: Implements the exact BLE protocol from Even Realities for text and bitmap display

import 'dart:async';
import 'dart:typed_data';
import 'dart:convert';
import 'dart:math';

import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';

import '../glasses_service.dart' as service;
import '../../models/glasses_connection_state.dart';
import '../../core/utils/logging_service.dart' as logging;

/// Even Realities specific glasses service implementing their BLE protocol
class EvenRealitiesGlassesService implements service.GlassesService {
  static const String _tag = 'EvenRealitiesGlassesService';

  // Even Realities specific UUIDs and constants
  static const String EVEN_SERVICE_UUID = "6E400001-B5A3-F393-E0A9-E50E24DCCA9E";
  static const String EVEN_TX_CHAR_UUID = "6E400002-B5A3-F393-E0A9-E50E24DCCA9E";
  static const String EVEN_RX_CHAR_UUID = "6E400003-B5A3-F393-E0A9-E50E24DCCA9E";
  
  // Protocol command bytes
  static const int CMD_TEXT_DISPLAY = 0x4E;
  static const int CMD_BITMAP_DATA = 0x15;
  static const int CMD_MIC_CONTROL = 0x0E;
  static const int CMD_MIC_DATA = 0xF1;
  static const int CMD_CONTROL = 0xF5;
  
  // Control sub-commands
  static const int CONTROL_START_AI = 0x01;
  static const int CONTROL_CLEAR_DISPLAY = 0x02;
  
  final logging.LoggingService _logger;

  // Service state
  bool _isInitialized = false;
  ConnectionStatus _connectionState = ConnectionStatus.disconnected;
  service.GlassesDevice? _connectedDevice;
  List<service.GlassesDevice> _discoveredDevices = [];

  // Bluetooth state
  bool _bluetoothEnabled = false;
  bool _hasPermissions = false;
  StreamSubscription<BluetoothAdapterState>? _bluetoothStateSubscription;
  StreamSubscription<List<ScanResult>>? _scanSubscription;

  // Connected device state
  BluetoothDevice? _bluetoothDevice;
  BluetoothCharacteristic? _txCharacteristic;
  BluetoothCharacteristic? _rxCharacteristic;
  StreamSubscription<BluetoothConnectionState>? _connectionSubscription;
  StreamSubscription<List<int>>? _dataSubscription;

  // Stream controllers
  final StreamController<ConnectionStatus> _connectionStateController = 
      StreamController<ConnectionStatus>.broadcast();
  final StreamController<List<service.GlassesDevice>> _discoveredDevicesController = 
      StreamController<List<service.GlassesDevice>>.broadcast();
  final StreamController<service.TouchGesture> _gestureController = 
      StreamController<service.TouchGesture>.broadcast();
  final StreamController<service.GlassesDeviceStatus> _deviceStatusController = 
      StreamController<service.GlassesDeviceStatus>.broadcast();

  // Current device status
  double _batteryLevel = 0.0;
  bool _isMicrophoneActive = false;

  EvenRealitiesGlassesService({required logging.LoggingService logger}) : _logger = logger;

  @override
  ConnectionStatus get connectionState => _connectionState;

  @override
  service.GlassesDevice? get connectedDevice => _connectedDevice;

  @override
  bool get isConnected => _connectionState == ConnectionStatus.connected;

  @override
  Stream<ConnectionStatus> get connectionStateStream => _connectionStateController.stream;

  @override
  Stream<List<service.GlassesDevice>> get discoveredDevicesStream => _discoveredDevicesController.stream;

  @override
  Stream<service.TouchGesture> get gestureStream => _gestureController.stream;

  @override
  Stream<service.GlassesDeviceStatus> get deviceStatusStream => _deviceStatusController.stream;

  @override
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      _logger.log(_tag, 'Initializing Even Realities glasses service', logging.LogLevel.info);

      // Check Bluetooth availability
      final isAvailable = await isBluetoothAvailable();
      if (!isAvailable) {
        throw Exception('Bluetooth not available');
      }

      // Request permissions
      final hasPermissions = await requestBluetoothPermission();
      if (!hasPermissions) {
        throw Exception('Bluetooth permissions not granted');
      }

      _isInitialized = true;
      _logger.log(_tag, 'Even Realities glasses service initialized', logging.LogLevel.info);
    } catch (e) {
      _logger.log(_tag, 'Failed to initialize glasses service: $e', logging.LogLevel.error);
      rethrow;
    }
  }

  @override
  Future<bool> isBluetoothAvailable() async {
    try {
      if (!_bluetoothEnabled) {
        final state = await FlutterBluePlus.adapterState.first;
        _bluetoothEnabled = state == BluetoothAdapterState.on;
      }
      return _bluetoothEnabled;
    } catch (e) {
      _logger.log(_tag, 'Error checking Bluetooth availability: $e', logging.LogLevel.error);
      return false;
    }
  }

  @override
  Future<bool> requestBluetoothPermission() async {
    try {
      final permissions = [
        Permission.bluetooth,
        Permission.bluetoothScan,
        Permission.bluetoothConnect,
        Permission.location,
      ];

      bool allGranted = true;
      for (final permission in permissions) {
        final status = await permission.request();
        if (status != PermissionStatus.granted) {
          allGranted = false;
          _logger.log(_tag, 'Permission denied: $permission', logging.LogLevel.warning);
        }
      }

      _hasPermissions = allGranted;
      return allGranted;
    } catch (e) {
      _logger.log(_tag, 'Error requesting Bluetooth permissions: $e', logging.LogLevel.error);
      return false;
    }
  }

  @override
  Future<void> startScanning({Duration timeout = const Duration(seconds: 30)}) async {
    if (!_isInitialized) {
      throw Exception('Service not initialized');
    }

    try {
      _logger.log(_tag, 'Starting scan for Even Realities glasses', logging.LogLevel.info);
      
      _discoveredDevices.clear();
      _discoveredDevicesController.add(_discoveredDevices);

      // Start scanning with Even Realities service UUID filter
      await FlutterBluePlus.startScan(
        withServices: [Guid(EVEN_SERVICE_UUID)],
        timeout: timeout,
      );

      _scanSubscription = FlutterBluePlus.scanResults.listen((results) {
        for (final result in results) {
          final device = service.GlassesDevice(
            id: result.device.remoteId.toString(),
            name: result.advertisementData.advName.isNotEmpty 
                ? result.advertisementData.advName 
                : 'Even Realities Glasses',
            signalStrength: result.rssi,
          );

          // Add if not already in list
          if (!_discoveredDevices.any((d) => d.id == device.id)) {
            _discoveredDevices.add(device);
            _discoveredDevicesController.add(_discoveredDevices);
            _logger.log(_tag, 'Found Even Realities device: ${device.name}', logging.LogLevel.info);
          }
        }
      });

    } catch (e) {
      _logger.log(_tag, 'Error starting scan: $e', logging.LogLevel.error);
      rethrow;
    }
  }

  @override
  Future<void> stopScanning() async {
    try {
      await FlutterBluePlus.stopScan();
      _scanSubscription?.cancel();
      _logger.log(_tag, 'Stopped scanning', logging.LogLevel.info);
    } catch (e) {
      _logger.log(_tag, 'Error stopping scan: $e', logging.LogLevel.error);
    }
  }

  @override
  Future<void> connectToDevice(String deviceId) async {
    try {
      _logger.log(_tag, 'Connecting to device: $deviceId', logging.LogLevel.info);
      
      final device = _discoveredDevices.firstWhere((d) => d.id == deviceId);
      final bluetoothDevice = BluetoothDevice.fromId(deviceId);
      
      _connectionState = ConnectionStatus.connecting;
      _connectionStateController.add(_connectionState);

      // Connect to device
      await bluetoothDevice.connect();
      _bluetoothDevice = bluetoothDevice;

      // Discover services
      final services = await bluetoothDevice.discoverServices();
      final evenService = services.firstWhere(
        (s) => s.uuid.toString().toUpperCase() == EVEN_SERVICE_UUID.toUpperCase(),
      );

      // Get characteristics
      final characteristics = evenService.characteristics;
      _txCharacteristic = characteristics.firstWhere(
        (c) => c.uuid.toString().toUpperCase() == EVEN_TX_CHAR_UUID.toUpperCase(),
      );
      _rxCharacteristic = characteristics.firstWhere(
        (c) => c.uuid.toString().toUpperCase() == EVEN_RX_CHAR_UUID.toUpperCase(),
      );

      // Enable notifications on RX characteristic
      await _rxCharacteristic!.setNotifyValue(true);
      _dataSubscription = _rxCharacteristic!.lastValueStream.listen(_handleReceivedData);

      // Monitor connection state
      _connectionSubscription = bluetoothDevice.connectionState.listen((state) {
        if (state == BluetoothConnectionState.connected) {
          _connectionState = ConnectionStatus.connected;
          _connectedDevice = device;
        } else {
          _connectionState = ConnectionStatus.disconnected;
          _connectedDevice = null;
        }
        _connectionStateController.add(_connectionState);
      });

      _logger.log(_tag, 'Connected to Even Realities glasses', logging.LogLevel.info);
    } catch (e) {
      _connectionState = ConnectionStatus.disconnected;
      _connectionStateController.add(_connectionState);
      _logger.log(_tag, 'Failed to connect: $e', logging.LogLevel.error);
      rethrow;
    }
  }

  @override
  Future<void> connectToLastDevice() async {
    // TODO: Implement last device connection with shared preferences
    throw UnimplementedError('connectToLastDevice not implemented yet');
  }

  @override
  Future<void> disconnect() async {
    try {
      _connectionSubscription?.cancel();
      _dataSubscription?.cancel();
      
      if (_bluetoothDevice?.isConnected == true) {
        await _bluetoothDevice!.disconnect();
      }
      
      _connectionState = ConnectionStatus.disconnected;
      _connectedDevice = null;
      _connectionStateController.add(_connectionState);
      
      _logger.log(_tag, 'Disconnected from glasses', logging.LogLevel.info);
    } catch (e) {
      _logger.log(_tag, 'Error disconnecting: $e', logging.LogLevel.error);
    }
  }

  /// Display text on Even Realities glasses using their protocol
  @override
  Future<void> displayText(
    String text, {
    service.HUDPosition position = service.HUDPosition.center,
    Duration? duration,
    service.HUDStyle? style,
  }) async {
    if (!isConnected || _txCharacteristic == null) {
      throw Exception('Glasses not connected');
    }

    try {
      _logger.log(_tag, 'Displaying text: $text', logging.LogLevel.info);
      
      // Convert text to UTF-8 bytes
      final textBytes = utf8.encode(text);
      
      // Create packet according to Even Realities protocol
      final packet = Uint8List(4 + textBytes.length);
      packet[0] = CMD_TEXT_DISPLAY; // Command byte
      packet[1] = textBytes.length; // Length
      packet[2] = 0x00; // Reserved
      packet[3] = 0x00; // Reserved
      
      // Copy text data
      for (int i = 0; i < textBytes.length; i++) {
        packet[4 + i] = textBytes[i];
      }

      // Send packet
      await _txCharacteristic!.write(packet, withoutResponse: false);
      
      _logger.log(_tag, 'Text sent to glasses successfully', logging.LogLevel.info);
    } catch (e) {
      _logger.log(_tag, 'Failed to send text: $e', logging.LogLevel.error);
      rethrow;
    }
  }

  /// Send bitmap data to Even Realities glasses
  Future<void> displayBitmap(Uint8List bitmapData) async {
    if (!isConnected || _txCharacteristic == null) {
      throw Exception('Glasses not connected');
    }

    try {
      _logger.log(_tag, 'Displaying bitmap data', logging.LogLevel.info);
      
      // Send bitmap in chunks according to protocol
      const maxChunkSize = 16; // BLE packet size limit
      
      for (int i = 0; i < bitmapData.length; i += maxChunkSize) {
        final endIndex = min(i + maxChunkSize, bitmapData.length);
        final chunk = bitmapData.sublist(i, endIndex);
        
        // Create packet for this chunk
        final packet = Uint8List(4 + chunk.length);
        packet[0] = CMD_BITMAP_DATA; // Command byte
        packet[1] = chunk.length; // Chunk length
        packet[2] = (i >> 8) & 0xFF; // Offset high byte
        packet[3] = i & 0xFF; // Offset low byte
        
        // Copy chunk data
        for (int j = 0; j < chunk.length; j++) {
          packet[4 + j] = chunk[j];
        }
        
        await _txCharacteristic!.write(packet, withoutResponse: false);
        
        // Small delay between chunks
        await Future.delayed(const Duration(milliseconds: 10));
      }
      
      _logger.log(_tag, 'Bitmap sent to glasses successfully', logging.LogLevel.info);
    } catch (e) {
      _logger.log(_tag, 'Failed to send bitmap: $e', logging.LogLevel.error);
      rethrow;
    }
  }

  @override
  Future<void> displayNotification(
    String title,
    String message, {
    service.NotificationPriority priority = service.NotificationPriority.normal,
    Duration duration = const Duration(seconds: 5),
  }) async {
    // Combine title and message for display
    final fullText = '$title\n$message';
    await displayText(fullText, duration: duration);
  }

  @override
  Future<void> clearDisplay() async {
    if (!isConnected || _txCharacteristic == null) {
      throw Exception('Glasses not connected');
    }

    try {
      _logger.log(_tag, 'Clearing display', logging.LogLevel.info);
      
      // Send clear display command
      final packet = Uint8List(4);
      packet[0] = CMD_CONTROL; // Control command
      packet[1] = 0x01; // Length
      packet[2] = CONTROL_CLEAR_DISPLAY; // Clear display sub-command
      packet[3] = 0x00; // Reserved
      
      await _txCharacteristic!.write(packet, withoutResponse: false);
      
      _logger.log(_tag, 'Display cleared', logging.LogLevel.info);
    } catch (e) {
      _logger.log(_tag, 'Failed to clear display: $e', logging.LogLevel.error);
      rethrow;
    }
  }

  /// Handle received data from glasses (touch events, etc.)
  void _handleReceivedData(List<int> data) {
    try {
      if (data.isEmpty) return;
      
      final command = data[0];
      
      switch (command) {
        case 0xF2: // Touch event
          _handleTouchEvent(data);
          break;
        case CMD_MIC_DATA: // Microphone data
          _handleMicrophoneData(data);
          break;
        default:
          _logger.log(_tag, 'Unknown command received: 0x${command.toRadixString(16)}', logging.LogLevel.debug);
      }
    } catch (e) {
      _logger.log(_tag, 'Error handling received data: $e', logging.LogLevel.error);
    }
  }

  void _handleTouchEvent(List<int> data) {
    if (data.length < 2) return;
    
    final touchType = data[1];
    service.TouchGesture? gesture;
    
    switch (touchType) {
      case 0x01:
        gesture = service.TouchGesture.tap;
        break;
      case 0x02:
        gesture = service.TouchGesture.doubleTap;
        break;
      case 0x03:
        gesture = service.TouchGesture.longPress;
        break;
      default:
        _logger.log(_tag, 'Unknown touch type: $touchType', logging.LogLevel.debug);
        return;
    }
    
    _gestureController.add(gesture);
    _logger.log(_tag, 'Touch gesture detected: $gesture', logging.LogLevel.debug);
  }

  void _handleMicrophoneData(List<int> data) {
    // Handle microphone data if needed
    _logger.log(_tag, 'Microphone data received: ${data.length} bytes', logging.LogLevel.debug);
  }

  // Implement other required methods from GlassesService interface
  @override
  Future<void> setBrightness(double brightness) async {
    // TODO: Implement brightness control if supported by Even Realities protocol
    _logger.log(_tag, 'setBrightness not implemented for Even Realities', logging.LogLevel.warning);
  }

  @override
  Future<void> configureGestures({
    bool enableTap = true,
    bool enableSwipe = true,
    bool enableLongPress = true,
    double sensitivity = 0.5,
  }) async {
    // TODO: Implement gesture configuration if supported
    _logger.log(_tag, 'configureGestures not implemented for Even Realities', logging.LogLevel.warning);
  }

  @override
  Future<void> sendCommand(String command, {Map<String, dynamic>? parameters}) async {
    // TODO: Implement custom commands
    _logger.log(_tag, 'sendCommand not implemented for Even Realities', logging.LogLevel.warning);
  }

  @override
  Future<service.GlassesDeviceInfo> getDeviceInfo() async {
    // TODO: Implement device info retrieval
    throw UnimplementedError('getDeviceInfo not implemented yet');
  }

  @override
  Future<double> getBatteryLevel() async {
    return _batteryLevel;
  }

  @override
  Future<service.GlassesHealthStatus> checkDeviceHealth() async {
    // TODO: Implement health check
    throw UnimplementedError('checkDeviceHealth not implemented yet');
  }

  @override
  Future<void> updateFirmware() async {
    // TODO: Implement firmware update if supported
    throw UnimplementedError('updateFirmware not implemented yet');
  }

  @override
  Future<void> dispose() async {
    await disconnect();
    await stopScanning();
    
    _connectionStateController.close();
    _discoveredDevicesController.close();
    _gestureController.close();
    _deviceStatusController.close();
    
    _bluetoothStateSubscription?.cancel();
    _scanSubscription?.cancel();
  }
} 