// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'glasses_connection_state.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$GlassesConnectionStateImpl _$$GlassesConnectionStateImplFromJson(
  Map<String, dynamic> json,
) => _$GlassesConnectionStateImpl(
  status:
      $enumDecodeNullable(_$ConnectionStatusEnumMap, json['status']) ??
      ConnectionStatus.disconnected,
  connectedDevice:
      json['connectedDevice'] == null
          ? null
          : GlassesDeviceInfo.fromJson(
            json['connectedDevice'] as Map<String, dynamic>,
          ),
  discoveredDevices:
      (json['discoveredDevices'] as List<dynamic>?)
          ?.map((e) => GlassesDeviceInfo.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const [],
  lastConnectedTime:
      json['lastConnectedTime'] == null
          ? null
          : DateTime.parse(json['lastConnectedTime'] as String),
  connectionAttempts: (json['connectionAttempts'] as num?)?.toInt() ?? 0,
  lastError: json['lastError'] as String?,
  errorTimestamp:
      json['errorTimestamp'] == null
          ? null
          : DateTime.parse(json['errorTimestamp'] as String),
  autoReconnectEnabled: json['autoReconnectEnabled'] as bool? ?? true,
  isScanning: json['isScanning'] as bool? ?? false,
  scanTimeout:
      json['scanTimeout'] == null
          ? const Duration(seconds: 30)
          : Duration(microseconds: (json['scanTimeout'] as num).toInt()),
  connectionQuality:
      json['connectionQuality'] == null
          ? null
          : ConnectionQuality.fromJson(
            json['connectionQuality'] as Map<String, dynamic>,
          ),
  hudState:
      json['hudState'] == null
          ? const HUDDisplayState()
          : HUDDisplayState.fromJson(json['hudState'] as Map<String, dynamic>),
  metadata: json['metadata'] as Map<String, dynamic>? ?? const {},
);

Map<String, dynamic> _$$GlassesConnectionStateImplToJson(
  _$GlassesConnectionStateImpl instance,
) => <String, dynamic>{
  'status': _$ConnectionStatusEnumMap[instance.status]!,
  'connectedDevice': instance.connectedDevice,
  'discoveredDevices': instance.discoveredDevices,
  'lastConnectedTime': instance.lastConnectedTime?.toIso8601String(),
  'connectionAttempts': instance.connectionAttempts,
  'lastError': instance.lastError,
  'errorTimestamp': instance.errorTimestamp?.toIso8601String(),
  'autoReconnectEnabled': instance.autoReconnectEnabled,
  'isScanning': instance.isScanning,
  'scanTimeout': instance.scanTimeout.inMicroseconds,
  'connectionQuality': instance.connectionQuality,
  'hudState': instance.hudState,
  'metadata': instance.metadata,
};

const _$ConnectionStatusEnumMap = {
  ConnectionStatus.disconnected: 'disconnected',
  ConnectionStatus.scanning: 'scanning',
  ConnectionStatus.connecting: 'connecting',
  ConnectionStatus.connected: 'connected',
  ConnectionStatus.disconnecting: 'disconnecting',
  ConnectionStatus.error: 'error',
  ConnectionStatus.unauthorized: 'unauthorized',
};

_$GlassesDeviceInfoImpl _$$GlassesDeviceInfoImplFromJson(
  Map<String, dynamic> json,
) => _$GlassesDeviceInfoImpl(
  deviceId: json['deviceId'] as String,
  name: json['name'] as String,
  modelNumber: json['modelNumber'] as String?,
  manufacturer: json['manufacturer'] as String? ?? 'Even Realities',
  firmwareVersion: json['firmwareVersion'] as String?,
  hardwareVersion: json['hardwareVersion'] as String?,
  serialNumber: json['serialNumber'] as String?,
  batteryLevel: (json['batteryLevel'] as num?)?.toDouble() ?? 0.0,
  batteryStatus:
      $enumDecodeNullable(_$BatteryStatusEnumMap, json['batteryStatus']) ??
      BatteryStatus.unknown,
  isCharging: json['isCharging'] as bool? ?? false,
  rssi: (json['rssi'] as num?)?.toInt() ?? -100,
  signalStrength:
      $enumDecodeNullable(_$SignalStrengthEnumMap, json['signalStrength']) ??
      SignalStrength.unknown,
  health:
      $enumDecodeNullable(_$DeviceHealthEnumMap, json['health']) ??
      DeviceHealth.unknown,
  isConnected: json['isConnected'] as bool? ?? false,
  lastSeen:
      json['lastSeen'] == null
          ? null
          : DateTime.parse(json['lastSeen'] as String),
  capabilities:
      json['capabilities'] == null
          ? const GlassesCapabilities()
          : GlassesCapabilities.fromJson(
            json['capabilities'] as Map<String, dynamic>,
          ),
  configuration:
      json['configuration'] == null
          ? const GlassesConfiguration()
          : GlassesConfiguration.fromJson(
            json['configuration'] as Map<String, dynamic>,
          ),
  metadata: json['metadata'] as Map<String, dynamic>? ?? const {},
);

Map<String, dynamic> _$$GlassesDeviceInfoImplToJson(
  _$GlassesDeviceInfoImpl instance,
) => <String, dynamic>{
  'deviceId': instance.deviceId,
  'name': instance.name,
  'modelNumber': instance.modelNumber,
  'manufacturer': instance.manufacturer,
  'firmwareVersion': instance.firmwareVersion,
  'hardwareVersion': instance.hardwareVersion,
  'serialNumber': instance.serialNumber,
  'batteryLevel': instance.batteryLevel,
  'batteryStatus': _$BatteryStatusEnumMap[instance.batteryStatus]!,
  'isCharging': instance.isCharging,
  'rssi': instance.rssi,
  'signalStrength': _$SignalStrengthEnumMap[instance.signalStrength]!,
  'health': _$DeviceHealthEnumMap[instance.health]!,
  'isConnected': instance.isConnected,
  'lastSeen': instance.lastSeen?.toIso8601String(),
  'capabilities': instance.capabilities,
  'configuration': instance.configuration,
  'metadata': instance.metadata,
};

const _$BatteryStatusEnumMap = {
  BatteryStatus.charging: 'charging',
  BatteryStatus.full: 'full',
  BatteryStatus.high: 'high',
  BatteryStatus.medium: 'medium',
  BatteryStatus.low: 'low',
  BatteryStatus.critical: 'critical',
  BatteryStatus.unknown: 'unknown',
};

const _$SignalStrengthEnumMap = {
  SignalStrength.excellent: 'excellent',
  SignalStrength.good: 'good',
  SignalStrength.fair: 'fair',
  SignalStrength.poor: 'poor',
  SignalStrength.unknown: 'unknown',
};

const _$DeviceHealthEnumMap = {
  DeviceHealth.excellent: 'excellent',
  DeviceHealth.good: 'good',
  DeviceHealth.warning: 'warning',
  DeviceHealth.critical: 'critical',
  DeviceHealth.unknown: 'unknown',
};

_$ConnectionQualityImpl _$$ConnectionQualityImplFromJson(
  Map<String, dynamic> json,
) => _$ConnectionQualityImpl(
  signalStrength:
      $enumDecodeNullable(_$SignalStrengthEnumMap, json['signalStrength']) ??
      SignalStrength.unknown,
  rssi: (json['rssi'] as num?)?.toInt() ?? -100,
  stabilityScore: (json['stabilityScore'] as num?)?.toDouble() ?? 0.0,
  packetLoss: (json['packetLoss'] as num?)?.toDouble() ?? 0.0,
  latencyMs: (json['latencyMs'] as num?)?.toInt() ?? 0,
  recentDisconnections: (json['recentDisconnections'] as num?)?.toInt() ?? 0,
  dataRate: (json['dataRate'] as num?)?.toInt() ?? 0,
  timestamp: DateTime.parse(json['timestamp'] as String),
);

Map<String, dynamic> _$$ConnectionQualityImplToJson(
  _$ConnectionQualityImpl instance,
) => <String, dynamic>{
  'signalStrength': _$SignalStrengthEnumMap[instance.signalStrength]!,
  'rssi': instance.rssi,
  'stabilityScore': instance.stabilityScore,
  'packetLoss': instance.packetLoss,
  'latencyMs': instance.latencyMs,
  'recentDisconnections': instance.recentDisconnections,
  'dataRate': instance.dataRate,
  'timestamp': instance.timestamp.toIso8601String(),
};

_$HUDDisplayStateImpl _$$HUDDisplayStateImplFromJson(
  Map<String, dynamic> json,
) => _$HUDDisplayStateImpl(
  isActive: json['isActive'] as bool? ?? false,
  brightness: (json['brightness'] as num?)?.toDouble() ?? 0.8,
  currentContent: json['currentContent'] as String?,
  contentType: $enumDecodeNullable(
    _$HUDContentTypeEnumMap,
    json['contentType'],
  ),
  position:
      $enumDecodeNullable(_$HUDPositionEnumMap, json['position']) ??
      HUDPosition.center,
  style:
      json['style'] == null
          ? const HUDStyleSettings()
          : HUDStyleSettings.fromJson(json['style'] as Map<String, dynamic>),
  isPaused: json['isPaused'] as bool? ?? false,
  lastUpdate:
      json['lastUpdate'] == null
          ? null
          : DateTime.parse(json['lastUpdate'] as String),
  displayQueue:
      (json['displayQueue'] as List<dynamic>?)
          ?.map((e) => HUDQueueItem.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const [],
);

Map<String, dynamic> _$$HUDDisplayStateImplToJson(
  _$HUDDisplayStateImpl instance,
) => <String, dynamic>{
  'isActive': instance.isActive,
  'brightness': instance.brightness,
  'currentContent': instance.currentContent,
  'contentType': _$HUDContentTypeEnumMap[instance.contentType],
  'position': _$HUDPositionEnumMap[instance.position]!,
  'style': instance.style,
  'isPaused': instance.isPaused,
  'lastUpdate': instance.lastUpdate?.toIso8601String(),
  'displayQueue': instance.displayQueue,
};

const _$HUDContentTypeEnumMap = {
  HUDContentType.text: 'text',
  HUDContentType.notification: 'notification',
  HUDContentType.menu: 'menu',
  HUDContentType.status: 'status',
  HUDContentType.image: 'image',
  HUDContentType.animation: 'animation',
};

const _$HUDPositionEnumMap = {
  HUDPosition.topLeft: 'topLeft',
  HUDPosition.topCenter: 'topCenter',
  HUDPosition.topRight: 'topRight',
  HUDPosition.centerLeft: 'centerLeft',
  HUDPosition.center: 'center',
  HUDPosition.centerRight: 'centerRight',
  HUDPosition.bottomLeft: 'bottomLeft',
  HUDPosition.bottomCenter: 'bottomCenter',
  HUDPosition.bottomRight: 'bottomRight',
};

_$HUDStyleSettingsImpl _$$HUDStyleSettingsImplFromJson(
  Map<String, dynamic> json,
) => _$HUDStyleSettingsImpl(
  fontSize: (json['fontSize'] as num?)?.toDouble() ?? 16.0,
  textColor: json['textColor'] as String? ?? '#FFFFFF',
  backgroundColor: json['backgroundColor'] as String? ?? '#000000',
  fontWeight: json['fontWeight'] as String? ?? 'normal',
  alignment: json['alignment'] as String? ?? 'center',
  displayDuration: (json['displayDuration'] as num?)?.toInt() ?? 5,
  animation: json['animation'] as String? ?? 'fade',
);

Map<String, dynamic> _$$HUDStyleSettingsImplToJson(
  _$HUDStyleSettingsImpl instance,
) => <String, dynamic>{
  'fontSize': instance.fontSize,
  'textColor': instance.textColor,
  'backgroundColor': instance.backgroundColor,
  'fontWeight': instance.fontWeight,
  'alignment': instance.alignment,
  'displayDuration': instance.displayDuration,
  'animation': instance.animation,
};

_$HUDQueueItemImpl _$$HUDQueueItemImplFromJson(Map<String, dynamic> json) =>
    _$HUDQueueItemImpl(
      content: json['content'] as String,
      type: $enumDecode(_$HUDContentTypeEnumMap, json['type']),
      position:
          $enumDecodeNullable(_$HUDPositionEnumMap, json['position']) ??
          HUDPosition.center,
      priority: (json['priority'] as num?)?.toInt() ?? 1,
      queuedAt: DateTime.parse(json['queuedAt'] as String),
      duration:
          json['duration'] == null
              ? const Duration(seconds: 5)
              : Duration(microseconds: (json['duration'] as num).toInt()),
      styleOverrides:
          json['styleOverrides'] == null
              ? null
              : HUDStyleSettings.fromJson(
                json['styleOverrides'] as Map<String, dynamic>,
              ),
    );

Map<String, dynamic> _$$HUDQueueItemImplToJson(_$HUDQueueItemImpl instance) =>
    <String, dynamic>{
      'content': instance.content,
      'type': _$HUDContentTypeEnumMap[instance.type]!,
      'position': _$HUDPositionEnumMap[instance.position]!,
      'priority': instance.priority,
      'queuedAt': instance.queuedAt.toIso8601String(),
      'duration': instance.duration.inMicroseconds,
      'styleOverrides': instance.styleOverrides,
    };

_$GlassesCapabilitiesImpl _$$GlassesCapabilitiesImplFromJson(
  Map<String, dynamic> json,
) => _$GlassesCapabilitiesImpl(
  supportsText: json['supportsText'] as bool? ?? true,
  supportsImages: json['supportsImages'] as bool? ?? false,
  supportsAnimations: json['supportsAnimations'] as bool? ?? false,
  supportsTouchGestures: json['supportsTouchGestures'] as bool? ?? true,
  supportsVoiceCommands: json['supportsVoiceCommands'] as bool? ?? false,
  maxTextLength: (json['maxTextLength'] as num?)?.toInt() ?? 256,
  supportedPositions:
      (json['supportedPositions'] as List<dynamic>?)
          ?.map((e) => $enumDecode(_$HUDPositionEnumMap, e))
          .toList() ??
      const [HUDPosition.center],
  supportsBatteryMonitoring: json['supportsBatteryMonitoring'] as bool? ?? true,
  supportsFirmwareUpdate: json['supportsFirmwareUpdate'] as bool? ?? true,
);

Map<String, dynamic> _$$GlassesCapabilitiesImplToJson(
  _$GlassesCapabilitiesImpl instance,
) => <String, dynamic>{
  'supportsText': instance.supportsText,
  'supportsImages': instance.supportsImages,
  'supportsAnimations': instance.supportsAnimations,
  'supportsTouchGestures': instance.supportsTouchGestures,
  'supportsVoiceCommands': instance.supportsVoiceCommands,
  'maxTextLength': instance.maxTextLength,
  'supportedPositions':
      instance.supportedPositions.map((e) => _$HUDPositionEnumMap[e]!).toList(),
  'supportsBatteryMonitoring': instance.supportsBatteryMonitoring,
  'supportsFirmwareUpdate': instance.supportsFirmwareUpdate,
};

_$GlassesConfigurationImpl _$$GlassesConfigurationImplFromJson(
  Map<String, dynamic> json,
) => _$GlassesConfigurationImpl(
  autoReconnect: json['autoReconnect'] as bool? ?? true,
  defaultBrightness: (json['defaultBrightness'] as num?)?.toDouble() ?? 0.8,
  gestureSensitivity: (json['gestureSensitivity'] as num?)?.toDouble() ?? 0.5,
  displayTimeout: (json['displayTimeout'] as num?)?.toInt() ?? 10,
  powerSaveMode: json['powerSaveMode'] as bool? ?? false,
  notifications:
      json['notifications'] == null
          ? const NotificationSettings()
          : NotificationSettings.fromJson(
            json['notifications'] as Map<String, dynamic>,
          ),
);

Map<String, dynamic> _$$GlassesConfigurationImplToJson(
  _$GlassesConfigurationImpl instance,
) => <String, dynamic>{
  'autoReconnect': instance.autoReconnect,
  'defaultBrightness': instance.defaultBrightness,
  'gestureSensitivity': instance.gestureSensitivity,
  'displayTimeout': instance.displayTimeout,
  'powerSaveMode': instance.powerSaveMode,
  'notifications': instance.notifications,
};

_$NotificationSettingsImpl _$$NotificationSettingsImplFromJson(
  Map<String, dynamic> json,
) => _$NotificationSettingsImpl(
  enabled: json['enabled'] as bool? ?? true,
  priorityThreshold: (json['priorityThreshold'] as num?)?.toInt() ?? 1,
  vibrationEnabled: json['vibrationEnabled'] as bool? ?? false,
  soundEnabled: json['soundEnabled'] as bool? ?? false,
);

Map<String, dynamic> _$$NotificationSettingsImplToJson(
  _$NotificationSettingsImpl instance,
) => <String, dynamic>{
  'enabled': instance.enabled,
  'priorityThreshold': instance.priorityThreshold,
  'vibrationEnabled': instance.vibrationEnabled,
  'soundEnabled': instance.soundEnabled,
};
