// ABOUTME: Glasses service interface for Even Realities smart glasses integration
// ABOUTME: Handles Bluetooth connectivity, HUD rendering, and device management

import 'dart:async';

import '../models/glasses_connection_state.dart';

/// HUD display content type
enum HUDContentType {
  text,
  notification,
  menu,
  status,
  image,
}

/// Touch gesture types from glasses
enum TouchGesture {
  tap,
  doubleTap,
  longPress,
  swipeLeft,
  swipeRight,
  swipeUp,
  swipeDown,
}

/// Service interface for Even Realities smart glasses
abstract class GlassesService {
  /// Current connection state
  ConnectionStatus get connectionState;
  
  /// Connected glasses device info
  GlassesDevice? get connectedDevice;
  
  /// Whether glasses are currently connected
  bool get isConnected;
  
  /// Stream of connection state changes
  Stream<ConnectionStatus> get connectionStateStream;
  
  /// Stream of discovered glasses devices
  Stream<List<GlassesDevice>> get discoveredDevicesStream;
  
  /// Stream of touch gestures from glasses
  Stream<TouchGesture> get gestureStream;
  
  /// Stream of device status updates (battery, etc.)
  Stream<GlassesDeviceStatus> get deviceStatusStream;

  /// Initialize the glasses service
  Future<void> initialize();

  /// Check if Bluetooth is available and enabled
  Future<bool> isBluetoothAvailable();

  /// Request Bluetooth permission
  Future<bool> requestBluetoothPermission();

  /// Start scanning for Even Realities glasses
  Future<void> startScanning({Duration timeout = const Duration(seconds: 30)});

  /// Stop scanning for devices
  Future<void> stopScanning();

  /// Connect to a specific glasses device
  Future<void> connectToDevice(String deviceId);

  /// Connect to the last known device
  Future<void> connectToLastDevice();

  /// Disconnect from current device
  Future<void> disconnect();

  /// Display text on the HUD
  Future<void> displayText(
    String text, {
    HUDPosition position = HUDPosition.center,
    Duration? duration,
    HUDStyle? style,
  });

  /// Display a notification on the HUD
  Future<void> displayNotification(
    String title,
    String message, {
    NotificationPriority priority = NotificationPriority.normal,
    Duration duration = const Duration(seconds: 5),
  });

  /// Clear the HUD display
  Future<void> clearDisplay();

  /// Set HUD brightness
  Future<void> setBrightness(double brightness); // 0.0 to 1.0

  /// Configure touch gesture settings
  Future<void> configureGestures({
    bool enableTap = true,
    bool enableSwipe = true,
    bool enableLongPress = true,
    double sensitivity = 0.5,
  });

  /// Send custom command to glasses
  Future<void> sendCommand(String command, {Map<String, dynamic>? parameters});

  /// Get device information
  Future<GlassesDeviceInfo> getDeviceInfo();

  /// Get battery level (0.0 to 1.0)
  Future<double> getBatteryLevel();

  /// Check device health and diagnostics
  Future<GlassesHealthStatus> checkDeviceHealth();

  /// Update device firmware (if available)
  Future<void> updateFirmware();

  /// Clean up resources
  Future<void> dispose();
}

/// Represents a discovered or connected glasses device
class GlassesDevice {
  final String id;
  final String name;
  final String? modelNumber;
  final int signalStrength; // RSSI value
  final bool isConnected;

  const GlassesDevice({
    required this.id,
    required this.name,
    this.modelNumber,
    required this.signalStrength,
    this.isConnected = false,
  });

  @override
  String toString() => 'GlassesDevice(id: $id, name: $name, rssi: $signalStrength)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GlassesDevice &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}

/// HUD display position
enum HUDPosition {
  topLeft,
  topCenter,
  topRight,
  centerLeft,
  center,
  centerRight,
  bottomLeft,
  bottomCenter,
  bottomRight,
}

/// HUD text style
class HUDStyle {
  final double fontSize;
  final String color;
  final String fontWeight;
  final String alignment;

  const HUDStyle({
    this.fontSize = 16.0,
    this.color = '#FFFFFF',
    this.fontWeight = 'normal',
    this.alignment = 'center',
  });
}

/// Notification priority levels
enum NotificationPriority {
  low,
  normal,
  high,
  urgent,
}

/// Device information
class GlassesDeviceInfo {
  final String deviceId;
  final String modelName;
  final String firmwareVersion;
  final String hardwareVersion;
  final String serialNumber;
  final DateTime lastConnected;

  const GlassesDeviceInfo({
    required this.deviceId,
    required this.modelName,
    required this.firmwareVersion,
    required this.hardwareVersion,
    required this.serialNumber,
    required this.lastConnected,
  });
}

/// Device status information
class GlassesDeviceStatus {
  final double batteryLevel;
  final bool isCharging;
  final int signalStrength;
  final String connectionQuality; // 'excellent', 'good', 'fair', 'poor'
  final DateTime lastUpdate;

  const GlassesDeviceStatus({
    required this.batteryLevel,
    required this.isCharging,
    required this.signalStrength,
    required this.connectionQuality,
    required this.lastUpdate,
  });
}

/// Device health status
class GlassesHealthStatus {
  final bool isHealthy;
  final List<String> issues;
  final Map<String, dynamic> diagnostics;
  final String overallStatus; // 'good', 'warning', 'error'

  const GlassesHealthStatus({
    required this.isHealthy,
    required this.issues,
    required this.diagnostics,
    required this.overallStatus,
  });
}