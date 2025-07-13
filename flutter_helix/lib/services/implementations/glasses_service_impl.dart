// ABOUTME: Bluetooth glasses service implementation for Even Realities smart glasses
// ABOUTME: Handles device discovery, connection management, HUD rendering, and gesture input

import 'dart:async';
import 'dart:convert';

import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';

import '../glasses_service.dart' as service;
import '../../models/glasses_connection_state.dart';
import '../../core/utils/logging_service.dart' as logging;
import '../../core/utils/constants.dart';

class GlassesServiceImpl implements service.GlassesService {
  static const String _tag = 'GlassesServiceImpl';

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
  double _currentBrightness = 0.8;
  bool _gesturesEnabled = true;

  GlassesServiceImpl({required logging.LoggingService logger}) : _logger = logger;

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
    try {
      _logger.log(_tag, 'Initializing glasses service', logging.LogLevel.info);

      // Check Bluetooth adapter state
      final adapterState = await FlutterBluePlus.adapterState.first;
      _bluetoothEnabled = adapterState == BluetoothAdapterState.on;

      // Listen to Bluetooth state changes
      _bluetoothStateSubscription = FlutterBluePlus.adapterState.listen(_onBluetoothStateChanged);

      // Request permissions
      _hasPermissions = await requestBluetoothPermission();

      _isInitialized = true;
      _logger.log(_tag, 'Glasses service initialized successfully', logging.LogLevel.info);
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
    try {
      if (!_isInitialized) {
        throw Exception('Service not initialized');
      }

      if (!_bluetoothEnabled) {
        _updateConnectionState(ConnectionStatus.error);
        throw Exception('Bluetooth not enabled');
      }

      if (!_hasPermissions) {
        _updateConnectionState(ConnectionStatus.unauthorized);
        throw Exception('Bluetooth permissions not granted');
      }

      _logger.log(_tag, 'Starting scan for Even Realities glasses', logging.LogLevel.info);
      _updateConnectionState(ConnectionStatus.scanning);
      _discoveredDevices.clear();
      _discoveredDevicesController.add(_discoveredDevices);

      // Start scanning with timeout
      await FlutterBluePlus.startScan(
        timeout: timeout,
        withServices: [Guid(BluetoothConstants.nordicUARTServiceUUID)],
      );

      // Listen to scan results
      _scanSubscription = FlutterBluePlus.scanResults.listen(_onScanResult);

      // Handle scan timeout
      Timer(timeout, () async {
        if (_connectionState == ConnectionStatus.scanning) {
          await stopScanning();
          if (_discoveredDevices.isEmpty) {
            _updateConnectionState(ConnectionStatus.disconnected);
            _logger.log(_tag, 'Scan completed - no devices found', logging.LogLevel.warning);
          } else {
            _logger.log(_tag, 'Scan completed - found ${_discoveredDevices.length} devices', logging.LogLevel.info);
          }
        }
      });
    } catch (e) {
      _logger.log(_tag, 'Error starting scan: $e', logging.LogLevel.error);
      _updateConnectionState(ConnectionStatus.error);
      rethrow;
    }
  }

  @override
  Future<void> stopScanning() async {
    try {
      await FlutterBluePlus.stopScan();
      await _scanSubscription?.cancel();
      _scanSubscription = null;
      
      if (_connectionState == ConnectionStatus.scanning) {
        _updateConnectionState(ConnectionStatus.disconnected);
      }
      
      _logger.log(_tag, 'Scan stopped', logging.LogLevel.info);
    } catch (e) {
      _logger.log(_tag, 'Error stopping scan: $e', logging.LogLevel.error);
    }
  }

  @override
  Future<void> connectToDevice(String deviceId) async {
    try {
      if (!_isInitialized) {
        throw Exception('Service not initialized');
      }

      final device = _discoveredDevices.firstWhere(
        (d) => d.id == deviceId,
        orElse: () => throw Exception('Device not found: $deviceId'),
      );

      _logger.log(_tag, 'Connecting to device: ${device.name}', logging.LogLevel.info);
      _updateConnectionState(ConnectionStatus.connecting);

      // Stop scanning if active
      if (_connectionState == ConnectionStatus.scanning) {
        await stopScanning();
      }

      // Get the Bluetooth device
      final scanResults = await FlutterBluePlus.scanResults.first;
      final scanResult = scanResults.firstWhere(
        (result) => result.device.remoteId.toString() == deviceId,
        orElse: () => throw Exception('Bluetooth device not found'),
      );

      _bluetoothDevice = scanResult.device;

      // Connect to device
      await _bluetoothDevice!.connect(timeout: BluetoothConstants.connectionTimeout);

      // Listen to connection state changes
      _connectionSubscription = _bluetoothDevice!.connectionState.listen(_onConnectionStateChanged);

      // Discover services and characteristics
      await _discoverServices();

      // Setup data communication
      await _setupDataCommunication();

      _connectedDevice = device;
      _updateConnectionState(ConnectionStatus.connected);

      // Start periodic device status monitoring
      _startDeviceStatusMonitoring();

      _logger.log(_tag, 'Successfully connected to ${device.name}', logging.LogLevel.info);
    } catch (e) {
      _logger.log(_tag, 'Failed to connect to device: $e', logging.LogLevel.error);
      _updateConnectionState(ConnectionStatus.error);
      rethrow;
    }
  }

  @override
  Future<void> connectToLastDevice() async {
    try {
      // This would typically load the last connected device from persistent storage
      // For now, just connect to the first discovered device if available
      if (_discoveredDevices.isNotEmpty) {
        await connectToDevice(_discoveredDevices.first.id);
      } else {
        throw Exception('No known devices to connect to');
      }
    } catch (e) {
      _logger.log(_tag, 'Failed to connect to last device: $e', logging.LogLevel.error);
      rethrow;
    }
  }

  @override
  Future<void> disconnect() async {
    try {
      _logger.log(_tag, 'Disconnecting from glasses', logging.LogLevel.info);
      _updateConnectionState(ConnectionStatus.disconnecting);

      await _connectionSubscription?.cancel();
      await _dataSubscription?.cancel();
      
      if (_bluetoothDevice != null) {
        await _bluetoothDevice!.disconnect();
      }

      _bluetoothDevice = null;
      _txCharacteristic = null;
      _rxCharacteristic = null;
      _connectedDevice = null;

      _updateConnectionState(ConnectionStatus.disconnected);
      _logger.log(_tag, 'Disconnected from glasses', logging.LogLevel.info);
    } catch (e) {
      _logger.log(_tag, 'Error during disconnect: $e', logging.LogLevel.error);
      _updateConnectionState(ConnectionStatus.error);
    }
  }

  @override
  Future<void> displayText(
    String text, {
    service.HUDPosition position = service.HUDPosition.center,
    Duration? duration,
    service.HUDStyle? style,
  }) async {
    try {
      if (!isConnected) {
        throw Exception('Device not connected');
      }

      final command = {
        'type': 'display_text',
        'content': text,
        'position': position.name,
        'duration': duration?.inSeconds ?? 5,
        'style': style != null ? {
          'fontSize': style.fontSize,
          'color': style.color,
          'fontWeight': style.fontWeight,
          'alignment': style.alignment,
        } : null,
      };

      await _sendCommand(command);
      _logger.log(_tag, 'Displayed text on HUD: $text', logging.LogLevel.debug);
    } catch (e) {
      _logger.log(_tag, 'Failed to display text: $e', logging.LogLevel.error);
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
    try {
      if (!isConnected) {
        throw Exception('Device not connected');
      }

      final command = {
        'type': 'display_notification',
        'title': title,
        'message': message,
        'priority': priority.name,
        'duration': duration.inSeconds,
      };

      await _sendCommand(command);
      _logger.log(_tag, 'Displayed notification: $title', logging.LogLevel.debug);
    } catch (e) {
      _logger.log(_tag, 'Failed to display notification: $e', logging.LogLevel.error);
      rethrow;
    }
  }

  @override
  Future<void> clearDisplay() async {
    try {
      if (!isConnected) {
        throw Exception('Device not connected');
      }

      final command = {'type': 'clear_display'};
      await _sendCommand(command);
      _logger.log(_tag, 'Cleared HUD display', logging.LogLevel.debug);
    } catch (e) {
      _logger.log(_tag, 'Failed to clear display: $e', logging.LogLevel.error);
      rethrow;
    }
  }

  @override
  Future<void> setBrightness(double brightness) async {
    try {
      if (!isConnected) {
        throw Exception('Device not connected');
      }

      _currentBrightness = brightness.clamp(0.0, 1.0);
      final command = {
        'type': 'set_brightness',
        'value': _currentBrightness,
      };

      await _sendCommand(command);
      _logger.log(_tag, 'Set brightness to: $_currentBrightness', logging.LogLevel.debug);
    } catch (e) {
      _logger.log(_tag, 'Failed to set brightness: $e', logging.LogLevel.error);
      rethrow;
    }
  }

  @override
  Future<void> configureGestures({
    bool enableTap = true,
    bool enableSwipe = true,
    bool enableLongPress = true,
    double sensitivity = 0.5,
  }) async {
    try {
      if (!isConnected) {
        throw Exception('Device not connected');
      }

      final command = {
        'type': 'configure_gestures',
        'enableTap': enableTap,
        'enableSwipe': enableSwipe,
        'enableLongPress': enableLongPress,
        'sensitivity': sensitivity.clamp(0.0, 1.0),
      };

      await _sendCommand(command);
      _gesturesEnabled = enableTap || enableSwipe || enableLongPress;
      _logger.log(_tag, 'Configured gestures', logging.LogLevel.debug);
    } catch (e) {
      _logger.log(_tag, 'Failed to configure gestures: $e', logging.LogLevel.error);
      rethrow;
    }
  }

  @override
  Future<void> sendCommand(String command, {Map<String, dynamic>? parameters}) async {
    try {
      if (!isConnected) {
        throw Exception('Device not connected');
      }

      final commandData = {
        'type': 'custom_command',
        'command': command,
        'parameters': parameters ?? {},
      };

      await _sendCommand(commandData);
      _logger.log(_tag, 'Sent custom command: $command', logging.LogLevel.debug);
    } catch (e) {
      _logger.log(_tag, 'Failed to send command: $e', logging.LogLevel.error);
      rethrow;
    }
  }

  @override
  Future<service.GlassesDeviceInfo> getDeviceInfo() async {
    try {
      if (!isConnected || _connectedDevice == null) {
        throw Exception('Device not connected');
      }

      // Request device info from glasses
      final command = {'type': 'get_device_info'};
      await _sendCommand(command);

      // In a real implementation, this would wait for a response
      // For now, return basic info
      return service.GlassesDeviceInfo(
        deviceId: _connectedDevice!.id,
        modelName: _connectedDevice!.modelNumber ?? 'G1',
        firmwareVersion: '1.0.0',
        hardwareVersion: '1.0',
        serialNumber: 'SN${DateTime.now().millisecondsSinceEpoch}',
        lastConnected: DateTime.now(),
      );
    } catch (e) {
      _logger.log(_tag, 'Failed to get device info: $e', logging.LogLevel.error);
      rethrow;
    }
  }

  @override
  Future<double> getBatteryLevel() async {
    try {
      if (!isConnected) {
        throw Exception('Device not connected');
      }

      final command = {'type': 'get_battery_level'};
      await _sendCommand(command);

      // In a real implementation, this would wait for a response
      return _batteryLevel;
    } catch (e) {
      _logger.log(_tag, 'Failed to get battery level: $e', logging.LogLevel.error);
      rethrow;
    }
  }

  @override
  Future<service.GlassesHealthStatus> checkDeviceHealth() async {
    try {
      if (!isConnected) {
        throw Exception('Device not connected');
      }

      final command = {'type': 'check_health'};
      await _sendCommand(command);

      // In a real implementation, this would analyze device status
      return service.GlassesHealthStatus(
        isHealthy: _batteryLevel > 0.1 && isConnected,
        issues: _batteryLevel < 0.2 ? ['Low battery'] : [],
        diagnostics: {
          'battery_level': _batteryLevel,
          'signal_strength': _connectedDevice?.signalStrength ?? -100,
          'connection_stable': isConnected,
        },
        overallStatus: _batteryLevel > 0.2 ? 'good' : 'warning',
      );
    } catch (e) {
      _logger.log(_tag, 'Failed to check device health: $e', logging.LogLevel.error);
      rethrow;
    }
  }

  @override
  Future<void> updateFirmware() async {
    try {
      if (!isConnected) {
        throw Exception('Device not connected');
      }

      _logger.log(_tag, 'Firmware update not implemented yet', logging.LogLevel.warning);
      throw UnimplementedError('Firmware update not yet implemented');
    } catch (e) {
      _logger.log(_tag, 'Failed to update firmware: $e', logging.LogLevel.error);
      rethrow;
    }
  }

  @override
  Future<void> dispose() async {
    try {
      await disconnect();
      await _bluetoothStateSubscription?.cancel();
      await _scanSubscription?.cancel();
      await _connectionStateController.close();
      await _discoveredDevicesController.close();
      await _gestureController.close();
      await _deviceStatusController.close();
      
      _logger.log(_tag, 'Glasses service disposed', logging.LogLevel.info);
    } catch (e) {
      _logger.log(_tag, 'Error disposing glasses service: $e', logging.LogLevel.error);
    }
  }

  // Private methods

  void _updateConnectionState(ConnectionStatus newState) {
    if (_connectionState != newState) {
      _connectionState = newState;
      _connectionStateController.add(newState);
      _logger.log(_tag, 'Connection state changed to: ${newState.name}', logging.LogLevel.debug);
    }
  }

  void _onBluetoothStateChanged(BluetoothAdapterState state) {
    _bluetoothEnabled = state == BluetoothAdapterState.on;
    _logger.log(_tag, 'Bluetooth state changed: $state', logging.LogLevel.debug);

    if (!_bluetoothEnabled && isConnected) {
      disconnect();
    }
  }

  void _onScanResult(List<ScanResult> results) {
    for (final result in results) {
      final device = result.device;
      
      // Filter for Even Realities devices
      if (_isEvenRealitiesDevice(device, result.advertisementData)) {
        final glassesDevice = service.GlassesDevice(
          id: device.remoteId.toString(),
          name: device.platformName.isNotEmpty ? device.platformName : 'Even Realities G1',
          modelNumber: 'G1',
          signalStrength: result.rssi,
          isConnected: false,
        );

        // Add or update device in discovered list
        final existingIndex = _discoveredDevices.indexWhere((d) => d.id == glassesDevice.id);
        if (existingIndex >= 0) {
          _discoveredDevices[existingIndex] = glassesDevice;
        } else {
          _discoveredDevices.add(glassesDevice);
          _logger.log(_tag, 'Discovered device: ${glassesDevice.name} (${glassesDevice.signalStrength} dBm)', logging.LogLevel.info);
        }

        _discoveredDevicesController.add(List.from(_discoveredDevices));
      }
    }
  }

  bool _isEvenRealitiesDevice(BluetoothDevice device, AdvertisementData adData) {
    // Check device name
    if (BluetoothConstants.targetDeviceNames.any((name) => 
        device.platformName.toLowerCase().contains(name.toLowerCase()))) {
      return true;
    }

    // Check manufacturer data
    if (adData.manufacturerData.isNotEmpty) {
      // Even Realities would have specific manufacturer ID
      return true; // Simplified for now
    }

    // Check service UUIDs
    if (adData.serviceUuids.contains(Guid(BluetoothConstants.nordicUARTServiceUUID))) {
      return true;
    }

    return false;
  }

  void _onConnectionStateChanged(BluetoothConnectionState state) {
    _logger.log(_tag, 'Bluetooth connection state: $state', logging.LogLevel.debug);

    switch (state) {
      case BluetoothConnectionState.connected:
        if (_connectionState == ConnectionStatus.connecting) {
          // Service setup will be completed in connectToDevice()
        }
        break;
      case BluetoothConnectionState.disconnected:
        if (isConnected) {
          _updateConnectionState(ConnectionStatus.disconnected);
          _connectedDevice = null;
        }
        break;
      case BluetoothConnectionState.connecting:
        // Handle connecting state
        break;
      case BluetoothConnectionState.disconnecting:
        // Handle disconnecting state
        _updateConnectionState(ConnectionStatus.disconnecting);
        break;
    }
  }

  Future<void> _discoverServices() async {
    if (_bluetoothDevice == null) return;

    final services = await _bluetoothDevice!.discoverServices();
    
    for (final service in services) {
      if (service.uuid.toString().toUpperCase() == BluetoothConstants.nordicUARTServiceUUID.toUpperCase()) {
        for (final characteristic in service.characteristics) {
          final uuid = characteristic.uuid.toString().toUpperCase();
          
          if (uuid == BluetoothConstants.nordicUARTTXCharacteristicUUID.toUpperCase()) {
            _txCharacteristic = characteristic;
          } else if (uuid == BluetoothConstants.nordicUARTRXCharacteristicUUID.toUpperCase()) {
            _rxCharacteristic = characteristic;
          }
        }
        break;
      }
    }

    if (_txCharacteristic == null || _rxCharacteristic == null) {
      throw Exception('Required characteristics not found');
    }

    _logger.log(_tag, 'Discovered Nordic UART service and characteristics', logging.LogLevel.debug);
  }

  Future<void> _setupDataCommunication() async {
    if (_rxCharacteristic == null) return;

    // Enable notifications on RX characteristic
    await _rxCharacteristic!.setNotifyValue(true);

    // Listen to incoming data
    _dataSubscription = _rxCharacteristic!.lastValueStream.listen(_onDataReceived);

    _logger.log(_tag, 'Data communication setup completed', logging.LogLevel.debug);
  }

  void _onDataReceived(List<int> data) {
    try {
      final message = utf8.decode(data);
      final parsed = jsonDecode(message);

      _logger.log(_tag, 'Received data: $message', logging.LogLevel.debug);

      // Handle different message types
      switch (parsed['type']) {
        case 'gesture':
          _handleGestureMessage(parsed);
          break;
        case 'battery_update':
          _handleBatteryUpdate(parsed);
          break;
        case 'status_update':
          _handleStatusUpdate(parsed);
          break;
        default:
          _logger.log(_tag, 'Unknown message type: ${parsed['type']}', logging.LogLevel.warning);
      }
    } catch (e) {
      _logger.log(_tag, 'Error processing received data: $e', logging.LogLevel.error);
    }
  }

  void _handleGestureMessage(Map<String, dynamic> data) {
    try {
      final gestureStr = data['gesture'] as String;
      final gesture = service.TouchGesture.values.firstWhere(
        (g) => g.name == gestureStr,
        orElse: () => service.TouchGesture.tap,
      );

      _gestureController.add(gesture);
      _logger.log(_tag, 'Received gesture: ${gesture.name}', logging.LogLevel.debug);
    } catch (e) {
      _logger.log(_tag, 'Error handling gesture message: $e', logging.LogLevel.error);
    }
  }

  void _handleBatteryUpdate(Map<String, dynamic> data) {
    try {
      _batteryLevel = (data['level'] as num).toDouble();
      _logger.log(_tag, 'Battery level updated: ${(_batteryLevel * 100).round()}%', logging.LogLevel.debug);
    } catch (e) {
      _logger.log(_tag, 'Error handling battery update: $e', logging.LogLevel.error);
    }
  }

  void _handleStatusUpdate(Map<String, dynamic> data) {
    try {
      final status = service.GlassesDeviceStatus(
        batteryLevel: _batteryLevel,
        isCharging: data['charging'] ?? false,
        signalStrength: data['rssi'] ?? -100,
        connectionQuality: data['quality'] ?? 'good',
        lastUpdate: DateTime.now(),
      );

      _deviceStatusController.add(status);
    } catch (e) {
      _logger.log(_tag, 'Error handling status update: $e', logging.LogLevel.error);
    }
  }

  Future<void> _sendCommand(Map<String, dynamic> command) async {
    if (_txCharacteristic == null) {
      throw Exception('TX characteristic not available');
    }

    try {
      final message = jsonEncode(command);
      final data = utf8.encode(message);
      
      await _txCharacteristic!.write(data, withoutResponse: false);
      _logger.log(_tag, 'Sent command: $message', logging.LogLevel.debug);
    } catch (e) {
      _logger.log(_tag, 'Error sending command: $e', logging.LogLevel.error);
      rethrow;
    }
  }

  void _startDeviceStatusMonitoring() {
    Timer.periodic(BluetoothConstants.heartbeatInterval, (timer) {
      if (!isConnected) {
        timer.cancel();
        return;
      }

      // Request status update
      _sendCommand({'type': 'get_status'}).catchError((e) {
        _logger.log(_tag, 'Error requesting status update: $e', logging.LogLevel.warning);
      });
    });
  }
}