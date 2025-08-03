// ABOUTME: Glasses connection state data model for Even Realities smart glasses
// ABOUTME: Manages connection status, device information, and real-time state

import 'package:freezed_annotation/freezed_annotation.dart';

part 'glasses_connection_state.freezed.dart';
part 'glasses_connection_state.g.dart';

/// Connection status for smart glasses
enum ConnectionStatus {
  disconnected,     // Not connected
  scanning,         // Searching for devices
  connecting,       // Attempting to connect
  connected,        // Successfully connected
  disconnecting,    // In process of disconnecting
  error,           // Connection error
  unauthorized,    // Bluetooth permissions denied
}

/// Bluetooth signal strength categories
enum SignalStrength {
  excellent,   // > -40 dBm
  good,        // -40 to -60 dBm
  fair,        // -60 to -80 dBm
  poor,        // < -80 dBm
  unknown,     // Cannot determine
}

/// Device health status
enum DeviceHealth {
  excellent,   // All systems normal
  good,        // Minor issues
  warning,     // Some concerns
  critical,    // Major problems
  unknown,     // Cannot determine
}

/// Battery status
enum BatteryStatus {
  charging,    // Currently charging
  full,        // 90-100%
  high,        // 70-89%
  medium,      // 30-69%
  low,         // 10-29%
  critical,    // < 10%
  unknown,     // Cannot determine
}

/// Main glasses connection state
@freezed
class GlassesConnectionState with _$GlassesConnectionState {
  const factory GlassesConnectionState({
    /// Current connection status
    @Default(ConnectionStatus.disconnected) ConnectionStatus status,
    
    /// Connected device information
    GlassesDeviceInfo? connectedDevice,
    
    /// List of discovered devices
    @Default([]) List<GlassesDeviceInfo> discoveredDevices,
    
    /// Last successful connection time
    DateTime? lastConnectedTime,
    
    /// Connection attempt count
    @Default(0) int connectionAttempts,
    
    /// Last error message
    String? lastError,
    
    /// Error timestamp
    DateTime? errorTimestamp,
    
    /// Whether auto-reconnect is enabled
    @Default(true) bool autoReconnectEnabled,
    
    /// Whether scanning is active
    @Default(false) bool isScanning,
    
    /// Scan timeout duration
    @Default(Duration(seconds: 30)) Duration scanTimeout,
    
    /// Connection quality metrics
    ConnectionQuality? connectionQuality,
    
    /// HUD display state
    @Default(HUDDisplayState()) HUDDisplayState hudState,
    
    /// Additional metadata
    @Default({}) Map<String, dynamic> metadata,
  }) = _GlassesConnectionState;

  factory GlassesConnectionState.fromJson(Map<String, dynamic> json) =>
      _$GlassesConnectionStateFromJson(json);

  const GlassesConnectionState._();

  /// Whether glasses are currently connected
  bool get isConnected => status == ConnectionStatus.connected;

  /// Whether connection is in progress
  bool get isConnecting => status == ConnectionStatus.connecting;

  /// Whether there's a connection error
  bool get hasError => status == ConnectionStatus.error;

  /// Whether connection is stable
  bool get isStable => isConnected && 
      connectionQuality != null && 
      connectionQuality!.isStable;

  /// Time since last connection
  Duration? get timeSinceLastConnection {
    if (lastConnectedTime == null) return null;
    return DateTime.now().difference(lastConnectedTime!);
  }

  /// Whether device needs attention (errors, low battery, etc.)
  bool get needsAttention {
    if (!isConnected) return false;
    if (connectedDevice == null) return false;
    
    return connectedDevice!.batteryLevel < 0.2 ||
           connectedDevice!.health == DeviceHealth.warning ||
           connectedDevice!.health == DeviceHealth.critical ||
           (connectionQuality?.signalStrength == SignalStrength.poor);
  }

  /// Get device by ID from discovered devices
  GlassesDeviceInfo? getDiscoveredDevice(String deviceId) {
    try {
      return discoveredDevices.firstWhere((d) => d.deviceId == deviceId);
    } catch (e) {
      return null;
    }
  }
}

/// Information about a glasses device
@freezed
class GlassesDeviceInfo with _$GlassesDeviceInfo {
  const factory GlassesDeviceInfo({
    /// Unique device identifier
    required String deviceId,
    
    /// Device name as advertised
    required String name,
    
    /// Model number
    String? modelNumber,
    
    /// Manufacturer name
    @Default('Even Realities') String manufacturer,
    
    /// Firmware version
    String? firmwareVersion,
    
    /// Hardware version
    String? hardwareVersion,
    
    /// Serial number
    String? serialNumber,
    
    /// Battery level (0.0 to 1.0)
    @Default(0.0) double batteryLevel,
    
    /// Battery status
    @Default(BatteryStatus.unknown) BatteryStatus batteryStatus,
    
    /// Whether device is charging
    @Default(false) bool isCharging,
    
    /// Signal strength (RSSI)
    @Default(-100) int rssi,
    
    /// Signal strength category
    @Default(SignalStrength.unknown) SignalStrength signalStrength,
    
    /// Device health status
    @Default(DeviceHealth.unknown) DeviceHealth health,
    
    /// Whether device is currently connected
    @Default(false) bool isConnected,
    
    /// Last seen timestamp
    DateTime? lastSeen,
    
    /// Device capabilities
    @Default(GlassesCapabilities()) GlassesCapabilities capabilities,
    
    /// Device configuration
    @Default(GlassesConfiguration()) GlassesConfiguration configuration,
    
    /// Additional device metadata
    @Default({}) Map<String, dynamic> metadata,
  }) = _GlassesDeviceInfo;

  factory GlassesDeviceInfo.fromJson(Map<String, dynamic> json) =>
      _$GlassesDeviceInfoFromJson(json);

  const GlassesDeviceInfo._();

  /// Battery percentage (0-100)
  int get batteryPercentage => (batteryLevel * 100).round();

  /// Whether battery is low
  bool get isBatteryLow => batteryLevel < 0.2;

  /// Whether battery is critical
  bool get isBatteryCritical => batteryLevel < 0.1;

  /// Whether device has good signal
  bool get hasGoodSignal => signalStrength == SignalStrength.excellent || 
                           signalStrength == SignalStrength.good;

  /// Signal strength as percentage
  int get signalPercentage {
    // Convert RSSI to percentage (rough approximation)
    if (rssi >= -40) return 100;
    if (rssi >= -50) return 90;
    if (rssi >= -60) return 70;
    if (rssi >= -70) return 50;
    if (rssi >= -80) return 30;
    if (rssi >= -90) return 10;
    return 0;
  }

  /// Device display name for UI
  String get displayName {
    if (name.isNotEmpty) return name;
    return 'Even Realities ${modelNumber ?? 'Glasses'}';
  }

  /// Whether device is healthy
  bool get isHealthy => health == DeviceHealth.excellent || 
                       health == DeviceHealth.good;

  /// Time since last seen
  Duration? get timeSinceLastSeen {
    if (lastSeen == null) return null;
    return DateTime.now().difference(lastSeen!);
  }
}

/// Connection quality metrics
@freezed
class ConnectionQuality with _$ConnectionQuality {
  const factory ConnectionQuality({
    /// Signal strength
    @Default(SignalStrength.unknown) SignalStrength signalStrength,
    
    /// Raw RSSI value
    @Default(-100) int rssi,
    
    /// Connection stability score (0.0 to 1.0)
    @Default(0.0) double stabilityScore,
    
    /// Packet loss percentage
    @Default(0.0) double packetLoss,
    
    /// Average latency in milliseconds
    @Default(0) int latencyMs,
    
    /// Number of disconnections in last hour
    @Default(0) int recentDisconnections,
    
    /// Data transfer rate (bytes/second)
    @Default(0) int dataRate,
    
    /// Quality assessment timestamp
    required DateTime timestamp,
  }) = _ConnectionQuality;

  factory ConnectionQuality.fromJson(Map<String, dynamic> json) =>
      _$ConnectionQualityFromJson(json);

  const ConnectionQuality._();

  /// Whether connection is stable
  bool get isStable => stabilityScore > 0.8 && packetLoss < 5.0;

  /// Whether connection is good quality
  bool get isGoodQuality => signalStrength == SignalStrength.excellent || 
                           signalStrength == SignalStrength.good;

  /// Overall quality score (0.0 to 1.0)
  double get overallQuality {
    double signalScore = signalStrength == SignalStrength.excellent ? 1.0 :
                        signalStrength == SignalStrength.good ? 0.8 :
                        signalStrength == SignalStrength.fair ? 0.5 : 0.2;
    
    double latencyScore = latencyMs < 50 ? 1.0 :
                         latencyMs < 100 ? 0.8 :
                         latencyMs < 200 ? 0.5 : 0.2;
    
    double lossScore = packetLoss < 1.0 ? 1.0 :
                      packetLoss < 5.0 ? 0.7 :
                      packetLoss < 10.0 ? 0.4 : 0.1;
    
    return (signalScore + stabilityScore + latencyScore + lossScore) / 4.0;
  }
}

/// HUD display state
@freezed
class HUDDisplayState with _$HUDDisplayState {
  const factory HUDDisplayState({
    /// Whether HUD is currently active
    @Default(false) bool isActive,
    
    /// Current brightness level (0.0 to 1.0)
    @Default(0.8) double brightness,
    
    /// Currently displayed content
    String? currentContent,
    
    /// Content type being displayed
    HUDContentType? contentType,
    
    /// Display position
    @Default(HUDPosition.center) HUDPosition position,
    
    /// Display style settings
    @Default(HUDStyleSettings()) HUDStyleSettings style,
    
    /// Whether display is temporarily paused
    @Default(false) bool isPaused,
    
    /// Last update timestamp
    DateTime? lastUpdate,
    
    /// Display queue for upcoming content
    @Default([]) List<HUDQueueItem> displayQueue,
  }) = _HUDDisplayState;

  factory HUDDisplayState.fromJson(Map<String, dynamic> json) =>
      _$HUDDisplayStateFromJson(json);

  const HUDDisplayState._();

  /// Whether there's content in the display queue
  bool get hasQueuedContent => displayQueue.isNotEmpty;

  /// Number of items in display queue
  int get queueLength => displayQueue.length;
}

/// HUD content types
enum HUDContentType {
  text,
  notification,
  menu,
  status,
  image,
  animation,
}

/// HUD display positions
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

/// HUD style settings
@freezed
class HUDStyleSettings with _$HUDStyleSettings {
  const factory HUDStyleSettings({
    /// Font size
    @Default(16.0) double fontSize,
    
    /// Text color
    @Default('#FFFFFF') String textColor,
    
    /// Background color
    @Default('#000000') String backgroundColor,
    
    /// Font weight
    @Default('normal') String fontWeight,
    
    /// Text alignment
    @Default('center') String alignment,
    
    /// Display duration in seconds
    @Default(5) int displayDuration,
    
    /// Animation type
    @Default('fade') String animation,
  }) = _HUDStyleSettings;

  factory HUDStyleSettings.fromJson(Map<String, dynamic> json) =>
      _$HUDStyleSettingsFromJson(json);
}

/// Item in HUD display queue
@freezed
class HUDQueueItem with _$HUDQueueItem {
  const factory HUDQueueItem({
    /// Content to display
    required String content,
    
    /// Content type
    required HUDContentType type,
    
    /// Display position
    @Default(HUDPosition.center) HUDPosition position,
    
    /// Priority (higher numbers = higher priority)
    @Default(1) int priority,
    
    /// When this item was queued
    required DateTime queuedAt,
    
    /// Display duration
    @Default(Duration(seconds: 5)) Duration duration,
    
    /// Style overrides
    HUDStyleSettings? styleOverrides,
  }) = _HUDQueueItem;

  factory HUDQueueItem.fromJson(Map<String, dynamic> json) =>
      _$HUDQueueItemFromJson(json);
}

/// Device capabilities
@freezed
class GlassesCapabilities with _$GlassesCapabilities {
  const factory GlassesCapabilities({
    /// Supports text display
    @Default(true) bool supportsText,
    
    /// Supports images
    @Default(false) bool supportsImages,
    
    /// Supports animations
    @Default(false) bool supportsAnimations,
    
    /// Supports touch gestures
    @Default(true) bool supportsTouchGestures,
    
    /// Supports voice commands
    @Default(false) bool supportsVoiceCommands,
    
    /// Maximum text length
    @Default(256) int maxTextLength,
    
    /// Supported display positions
    @Default([HUDPosition.center]) List<HUDPosition> supportedPositions,
    
    /// Battery monitoring capability
    @Default(true) bool supportsBatteryMonitoring,
    
    /// Firmware update capability
    @Default(true) bool supportsFirmwareUpdate,
  }) = _GlassesCapabilities;

  factory GlassesCapabilities.fromJson(Map<String, dynamic> json) =>
      _$GlassesCapabilitiesFromJson(json);
}

/// Device configuration
@freezed
class GlassesConfiguration with _$GlassesConfiguration {
  const factory GlassesConfiguration({
    /// Auto-reconnect setting
    @Default(true) bool autoReconnect,
    
    /// Default brightness
    @Default(0.8) double defaultBrightness,
    
    /// Gesture sensitivity
    @Default(0.5) double gestureSensitivity,
    
    /// Display timeout in seconds
    @Default(10) int displayTimeout,
    
    /// Power save mode enabled
    @Default(false) bool powerSaveMode,
    
    /// Notification settings
    @Default(NotificationSettings()) NotificationSettings notifications,
  }) = _GlassesConfiguration;

  factory GlassesConfiguration.fromJson(Map<String, dynamic> json) =>
      _$GlassesConfigurationFromJson(json);
}

/// Notification settings
@freezed
class NotificationSettings with _$NotificationSettings {
  const factory NotificationSettings({
    /// Enable notifications
    @Default(true) bool enabled,
    
    /// Priority threshold
    @Default(1) int priorityThreshold,
    
    /// Vibration enabled
    @Default(false) bool vibrationEnabled,
    
    /// Sound enabled
    @Default(false) bool soundEnabled,
  }) = _NotificationSettings;

  factory NotificationSettings.fromJson(Map<String, dynamic> json) =>
      _$NotificationSettingsFromJson(json);
}