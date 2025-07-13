// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'glasses_connection_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

GlassesConnectionState _$GlassesConnectionStateFromJson(
  Map<String, dynamic> json,
) {
  return _GlassesConnectionState.fromJson(json);
}

/// @nodoc
mixin _$GlassesConnectionState {
  /// Current connection status
  ConnectionStatus get status => throw _privateConstructorUsedError;

  /// Connected device information
  GlassesDeviceInfo? get connectedDevice => throw _privateConstructorUsedError;

  /// List of discovered devices
  List<GlassesDeviceInfo> get discoveredDevices =>
      throw _privateConstructorUsedError;

  /// Last successful connection time
  DateTime? get lastConnectedTime => throw _privateConstructorUsedError;

  /// Connection attempt count
  int get connectionAttempts => throw _privateConstructorUsedError;

  /// Last error message
  String? get lastError => throw _privateConstructorUsedError;

  /// Error timestamp
  DateTime? get errorTimestamp => throw _privateConstructorUsedError;

  /// Whether auto-reconnect is enabled
  bool get autoReconnectEnabled => throw _privateConstructorUsedError;

  /// Whether scanning is active
  bool get isScanning => throw _privateConstructorUsedError;

  /// Scan timeout duration
  Duration get scanTimeout => throw _privateConstructorUsedError;

  /// Connection quality metrics
  ConnectionQuality? get connectionQuality =>
      throw _privateConstructorUsedError;

  /// HUD display state
  HUDDisplayState get hudState => throw _privateConstructorUsedError;

  /// Additional metadata
  Map<String, dynamic> get metadata => throw _privateConstructorUsedError;

  /// Serializes this GlassesConnectionState to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of GlassesConnectionState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $GlassesConnectionStateCopyWith<GlassesConnectionState> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $GlassesConnectionStateCopyWith<$Res> {
  factory $GlassesConnectionStateCopyWith(
    GlassesConnectionState value,
    $Res Function(GlassesConnectionState) then,
  ) = _$GlassesConnectionStateCopyWithImpl<$Res, GlassesConnectionState>;
  @useResult
  $Res call({
    ConnectionStatus status,
    GlassesDeviceInfo? connectedDevice,
    List<GlassesDeviceInfo> discoveredDevices,
    DateTime? lastConnectedTime,
    int connectionAttempts,
    String? lastError,
    DateTime? errorTimestamp,
    bool autoReconnectEnabled,
    bool isScanning,
    Duration scanTimeout,
    ConnectionQuality? connectionQuality,
    HUDDisplayState hudState,
    Map<String, dynamic> metadata,
  });

  $GlassesDeviceInfoCopyWith<$Res>? get connectedDevice;
  $ConnectionQualityCopyWith<$Res>? get connectionQuality;
  $HUDDisplayStateCopyWith<$Res> get hudState;
}

/// @nodoc
class _$GlassesConnectionStateCopyWithImpl<
  $Res,
  $Val extends GlassesConnectionState
>
    implements $GlassesConnectionStateCopyWith<$Res> {
  _$GlassesConnectionStateCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of GlassesConnectionState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? status = null,
    Object? connectedDevice = freezed,
    Object? discoveredDevices = null,
    Object? lastConnectedTime = freezed,
    Object? connectionAttempts = null,
    Object? lastError = freezed,
    Object? errorTimestamp = freezed,
    Object? autoReconnectEnabled = null,
    Object? isScanning = null,
    Object? scanTimeout = null,
    Object? connectionQuality = freezed,
    Object? hudState = null,
    Object? metadata = null,
  }) {
    return _then(
      _value.copyWith(
            status:
                null == status
                    ? _value.status
                    : status // ignore: cast_nullable_to_non_nullable
                        as ConnectionStatus,
            connectedDevice:
                freezed == connectedDevice
                    ? _value.connectedDevice
                    : connectedDevice // ignore: cast_nullable_to_non_nullable
                        as GlassesDeviceInfo?,
            discoveredDevices:
                null == discoveredDevices
                    ? _value.discoveredDevices
                    : discoveredDevices // ignore: cast_nullable_to_non_nullable
                        as List<GlassesDeviceInfo>,
            lastConnectedTime:
                freezed == lastConnectedTime
                    ? _value.lastConnectedTime
                    : lastConnectedTime // ignore: cast_nullable_to_non_nullable
                        as DateTime?,
            connectionAttempts:
                null == connectionAttempts
                    ? _value.connectionAttempts
                    : connectionAttempts // ignore: cast_nullable_to_non_nullable
                        as int,
            lastError:
                freezed == lastError
                    ? _value.lastError
                    : lastError // ignore: cast_nullable_to_non_nullable
                        as String?,
            errorTimestamp:
                freezed == errorTimestamp
                    ? _value.errorTimestamp
                    : errorTimestamp // ignore: cast_nullable_to_non_nullable
                        as DateTime?,
            autoReconnectEnabled:
                null == autoReconnectEnabled
                    ? _value.autoReconnectEnabled
                    : autoReconnectEnabled // ignore: cast_nullable_to_non_nullable
                        as bool,
            isScanning:
                null == isScanning
                    ? _value.isScanning
                    : isScanning // ignore: cast_nullable_to_non_nullable
                        as bool,
            scanTimeout:
                null == scanTimeout
                    ? _value.scanTimeout
                    : scanTimeout // ignore: cast_nullable_to_non_nullable
                        as Duration,
            connectionQuality:
                freezed == connectionQuality
                    ? _value.connectionQuality
                    : connectionQuality // ignore: cast_nullable_to_non_nullable
                        as ConnectionQuality?,
            hudState:
                null == hudState
                    ? _value.hudState
                    : hudState // ignore: cast_nullable_to_non_nullable
                        as HUDDisplayState,
            metadata:
                null == metadata
                    ? _value.metadata
                    : metadata // ignore: cast_nullable_to_non_nullable
                        as Map<String, dynamic>,
          )
          as $Val,
    );
  }

  /// Create a copy of GlassesConnectionState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $GlassesDeviceInfoCopyWith<$Res>? get connectedDevice {
    if (_value.connectedDevice == null) {
      return null;
    }

    return $GlassesDeviceInfoCopyWith<$Res>(_value.connectedDevice!, (value) {
      return _then(_value.copyWith(connectedDevice: value) as $Val);
    });
  }

  /// Create a copy of GlassesConnectionState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $ConnectionQualityCopyWith<$Res>? get connectionQuality {
    if (_value.connectionQuality == null) {
      return null;
    }

    return $ConnectionQualityCopyWith<$Res>(_value.connectionQuality!, (value) {
      return _then(_value.copyWith(connectionQuality: value) as $Val);
    });
  }

  /// Create a copy of GlassesConnectionState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $HUDDisplayStateCopyWith<$Res> get hudState {
    return $HUDDisplayStateCopyWith<$Res>(_value.hudState, (value) {
      return _then(_value.copyWith(hudState: value) as $Val);
    });
  }
}

/// @nodoc
abstract class _$$GlassesConnectionStateImplCopyWith<$Res>
    implements $GlassesConnectionStateCopyWith<$Res> {
  factory _$$GlassesConnectionStateImplCopyWith(
    _$GlassesConnectionStateImpl value,
    $Res Function(_$GlassesConnectionStateImpl) then,
  ) = __$$GlassesConnectionStateImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    ConnectionStatus status,
    GlassesDeviceInfo? connectedDevice,
    List<GlassesDeviceInfo> discoveredDevices,
    DateTime? lastConnectedTime,
    int connectionAttempts,
    String? lastError,
    DateTime? errorTimestamp,
    bool autoReconnectEnabled,
    bool isScanning,
    Duration scanTimeout,
    ConnectionQuality? connectionQuality,
    HUDDisplayState hudState,
    Map<String, dynamic> metadata,
  });

  @override
  $GlassesDeviceInfoCopyWith<$Res>? get connectedDevice;
  @override
  $ConnectionQualityCopyWith<$Res>? get connectionQuality;
  @override
  $HUDDisplayStateCopyWith<$Res> get hudState;
}

/// @nodoc
class __$$GlassesConnectionStateImplCopyWithImpl<$Res>
    extends
        _$GlassesConnectionStateCopyWithImpl<$Res, _$GlassesConnectionStateImpl>
    implements _$$GlassesConnectionStateImplCopyWith<$Res> {
  __$$GlassesConnectionStateImplCopyWithImpl(
    _$GlassesConnectionStateImpl _value,
    $Res Function(_$GlassesConnectionStateImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of GlassesConnectionState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? status = null,
    Object? connectedDevice = freezed,
    Object? discoveredDevices = null,
    Object? lastConnectedTime = freezed,
    Object? connectionAttempts = null,
    Object? lastError = freezed,
    Object? errorTimestamp = freezed,
    Object? autoReconnectEnabled = null,
    Object? isScanning = null,
    Object? scanTimeout = null,
    Object? connectionQuality = freezed,
    Object? hudState = null,
    Object? metadata = null,
  }) {
    return _then(
      _$GlassesConnectionStateImpl(
        status:
            null == status
                ? _value.status
                : status // ignore: cast_nullable_to_non_nullable
                    as ConnectionStatus,
        connectedDevice:
            freezed == connectedDevice
                ? _value.connectedDevice
                : connectedDevice // ignore: cast_nullable_to_non_nullable
                    as GlassesDeviceInfo?,
        discoveredDevices:
            null == discoveredDevices
                ? _value._discoveredDevices
                : discoveredDevices // ignore: cast_nullable_to_non_nullable
                    as List<GlassesDeviceInfo>,
        lastConnectedTime:
            freezed == lastConnectedTime
                ? _value.lastConnectedTime
                : lastConnectedTime // ignore: cast_nullable_to_non_nullable
                    as DateTime?,
        connectionAttempts:
            null == connectionAttempts
                ? _value.connectionAttempts
                : connectionAttempts // ignore: cast_nullable_to_non_nullable
                    as int,
        lastError:
            freezed == lastError
                ? _value.lastError
                : lastError // ignore: cast_nullable_to_non_nullable
                    as String?,
        errorTimestamp:
            freezed == errorTimestamp
                ? _value.errorTimestamp
                : errorTimestamp // ignore: cast_nullable_to_non_nullable
                    as DateTime?,
        autoReconnectEnabled:
            null == autoReconnectEnabled
                ? _value.autoReconnectEnabled
                : autoReconnectEnabled // ignore: cast_nullable_to_non_nullable
                    as bool,
        isScanning:
            null == isScanning
                ? _value.isScanning
                : isScanning // ignore: cast_nullable_to_non_nullable
                    as bool,
        scanTimeout:
            null == scanTimeout
                ? _value.scanTimeout
                : scanTimeout // ignore: cast_nullable_to_non_nullable
                    as Duration,
        connectionQuality:
            freezed == connectionQuality
                ? _value.connectionQuality
                : connectionQuality // ignore: cast_nullable_to_non_nullable
                    as ConnectionQuality?,
        hudState:
            null == hudState
                ? _value.hudState
                : hudState // ignore: cast_nullable_to_non_nullable
                    as HUDDisplayState,
        metadata:
            null == metadata
                ? _value._metadata
                : metadata // ignore: cast_nullable_to_non_nullable
                    as Map<String, dynamic>,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$GlassesConnectionStateImpl extends _GlassesConnectionState {
  const _$GlassesConnectionStateImpl({
    this.status = ConnectionStatus.disconnected,
    this.connectedDevice,
    final List<GlassesDeviceInfo> discoveredDevices = const [],
    this.lastConnectedTime,
    this.connectionAttempts = 0,
    this.lastError,
    this.errorTimestamp,
    this.autoReconnectEnabled = true,
    this.isScanning = false,
    this.scanTimeout = const Duration(seconds: 30),
    this.connectionQuality,
    this.hudState = const HUDDisplayState(),
    final Map<String, dynamic> metadata = const {},
  }) : _discoveredDevices = discoveredDevices,
       _metadata = metadata,
       super._();

  factory _$GlassesConnectionStateImpl.fromJson(Map<String, dynamic> json) =>
      _$$GlassesConnectionStateImplFromJson(json);

  /// Current connection status
  @override
  @JsonKey()
  final ConnectionStatus status;

  /// Connected device information
  @override
  final GlassesDeviceInfo? connectedDevice;

  /// List of discovered devices
  final List<GlassesDeviceInfo> _discoveredDevices;

  /// List of discovered devices
  @override
  @JsonKey()
  List<GlassesDeviceInfo> get discoveredDevices {
    if (_discoveredDevices is EqualUnmodifiableListView)
      return _discoveredDevices;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_discoveredDevices);
  }

  /// Last successful connection time
  @override
  final DateTime? lastConnectedTime;

  /// Connection attempt count
  @override
  @JsonKey()
  final int connectionAttempts;

  /// Last error message
  @override
  final String? lastError;

  /// Error timestamp
  @override
  final DateTime? errorTimestamp;

  /// Whether auto-reconnect is enabled
  @override
  @JsonKey()
  final bool autoReconnectEnabled;

  /// Whether scanning is active
  @override
  @JsonKey()
  final bool isScanning;

  /// Scan timeout duration
  @override
  @JsonKey()
  final Duration scanTimeout;

  /// Connection quality metrics
  @override
  final ConnectionQuality? connectionQuality;

  /// HUD display state
  @override
  @JsonKey()
  final HUDDisplayState hudState;

  /// Additional metadata
  final Map<String, dynamic> _metadata;

  /// Additional metadata
  @override
  @JsonKey()
  Map<String, dynamic> get metadata {
    if (_metadata is EqualUnmodifiableMapView) return _metadata;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(_metadata);
  }

  @override
  String toString() {
    return 'GlassesConnectionState(status: $status, connectedDevice: $connectedDevice, discoveredDevices: $discoveredDevices, lastConnectedTime: $lastConnectedTime, connectionAttempts: $connectionAttempts, lastError: $lastError, errorTimestamp: $errorTimestamp, autoReconnectEnabled: $autoReconnectEnabled, isScanning: $isScanning, scanTimeout: $scanTimeout, connectionQuality: $connectionQuality, hudState: $hudState, metadata: $metadata)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$GlassesConnectionStateImpl &&
            (identical(other.status, status) || other.status == status) &&
            (identical(other.connectedDevice, connectedDevice) ||
                other.connectedDevice == connectedDevice) &&
            const DeepCollectionEquality().equals(
              other._discoveredDevices,
              _discoveredDevices,
            ) &&
            (identical(other.lastConnectedTime, lastConnectedTime) ||
                other.lastConnectedTime == lastConnectedTime) &&
            (identical(other.connectionAttempts, connectionAttempts) ||
                other.connectionAttempts == connectionAttempts) &&
            (identical(other.lastError, lastError) ||
                other.lastError == lastError) &&
            (identical(other.errorTimestamp, errorTimestamp) ||
                other.errorTimestamp == errorTimestamp) &&
            (identical(other.autoReconnectEnabled, autoReconnectEnabled) ||
                other.autoReconnectEnabled == autoReconnectEnabled) &&
            (identical(other.isScanning, isScanning) ||
                other.isScanning == isScanning) &&
            (identical(other.scanTimeout, scanTimeout) ||
                other.scanTimeout == scanTimeout) &&
            (identical(other.connectionQuality, connectionQuality) ||
                other.connectionQuality == connectionQuality) &&
            (identical(other.hudState, hudState) ||
                other.hudState == hudState) &&
            const DeepCollectionEquality().equals(other._metadata, _metadata));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    status,
    connectedDevice,
    const DeepCollectionEquality().hash(_discoveredDevices),
    lastConnectedTime,
    connectionAttempts,
    lastError,
    errorTimestamp,
    autoReconnectEnabled,
    isScanning,
    scanTimeout,
    connectionQuality,
    hudState,
    const DeepCollectionEquality().hash(_metadata),
  );

  /// Create a copy of GlassesConnectionState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$GlassesConnectionStateImplCopyWith<_$GlassesConnectionStateImpl>
  get copyWith =>
      __$$GlassesConnectionStateImplCopyWithImpl<_$GlassesConnectionStateImpl>(
        this,
        _$identity,
      );

  @override
  Map<String, dynamic> toJson() {
    return _$$GlassesConnectionStateImplToJson(this);
  }
}

abstract class _GlassesConnectionState extends GlassesConnectionState {
  const factory _GlassesConnectionState({
    final ConnectionStatus status,
    final GlassesDeviceInfo? connectedDevice,
    final List<GlassesDeviceInfo> discoveredDevices,
    final DateTime? lastConnectedTime,
    final int connectionAttempts,
    final String? lastError,
    final DateTime? errorTimestamp,
    final bool autoReconnectEnabled,
    final bool isScanning,
    final Duration scanTimeout,
    final ConnectionQuality? connectionQuality,
    final HUDDisplayState hudState,
    final Map<String, dynamic> metadata,
  }) = _$GlassesConnectionStateImpl;
  const _GlassesConnectionState._() : super._();

  factory _GlassesConnectionState.fromJson(Map<String, dynamic> json) =
      _$GlassesConnectionStateImpl.fromJson;

  /// Current connection status
  @override
  ConnectionStatus get status;

  /// Connected device information
  @override
  GlassesDeviceInfo? get connectedDevice;

  /// List of discovered devices
  @override
  List<GlassesDeviceInfo> get discoveredDevices;

  /// Last successful connection time
  @override
  DateTime? get lastConnectedTime;

  /// Connection attempt count
  @override
  int get connectionAttempts;

  /// Last error message
  @override
  String? get lastError;

  /// Error timestamp
  @override
  DateTime? get errorTimestamp;

  /// Whether auto-reconnect is enabled
  @override
  bool get autoReconnectEnabled;

  /// Whether scanning is active
  @override
  bool get isScanning;

  /// Scan timeout duration
  @override
  Duration get scanTimeout;

  /// Connection quality metrics
  @override
  ConnectionQuality? get connectionQuality;

  /// HUD display state
  @override
  HUDDisplayState get hudState;

  /// Additional metadata
  @override
  Map<String, dynamic> get metadata;

  /// Create a copy of GlassesConnectionState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$GlassesConnectionStateImplCopyWith<_$GlassesConnectionStateImpl>
  get copyWith => throw _privateConstructorUsedError;
}

GlassesDeviceInfo _$GlassesDeviceInfoFromJson(Map<String, dynamic> json) {
  return _GlassesDeviceInfo.fromJson(json);
}

/// @nodoc
mixin _$GlassesDeviceInfo {
  /// Unique device identifier
  String get deviceId => throw _privateConstructorUsedError;

  /// Device name as advertised
  String get name => throw _privateConstructorUsedError;

  /// Model number
  String? get modelNumber => throw _privateConstructorUsedError;

  /// Manufacturer name
  String get manufacturer => throw _privateConstructorUsedError;

  /// Firmware version
  String? get firmwareVersion => throw _privateConstructorUsedError;

  /// Hardware version
  String? get hardwareVersion => throw _privateConstructorUsedError;

  /// Serial number
  String? get serialNumber => throw _privateConstructorUsedError;

  /// Battery level (0.0 to 1.0)
  double get batteryLevel => throw _privateConstructorUsedError;

  /// Battery status
  BatteryStatus get batteryStatus => throw _privateConstructorUsedError;

  /// Whether device is charging
  bool get isCharging => throw _privateConstructorUsedError;

  /// Signal strength (RSSI)
  int get rssi => throw _privateConstructorUsedError;

  /// Signal strength category
  SignalStrength get signalStrength => throw _privateConstructorUsedError;

  /// Device health status
  DeviceHealth get health => throw _privateConstructorUsedError;

  /// Whether device is currently connected
  bool get isConnected => throw _privateConstructorUsedError;

  /// Last seen timestamp
  DateTime? get lastSeen => throw _privateConstructorUsedError;

  /// Device capabilities
  GlassesCapabilities get capabilities => throw _privateConstructorUsedError;

  /// Device configuration
  GlassesConfiguration get configuration => throw _privateConstructorUsedError;

  /// Additional device metadata
  Map<String, dynamic> get metadata => throw _privateConstructorUsedError;

  /// Serializes this GlassesDeviceInfo to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of GlassesDeviceInfo
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $GlassesDeviceInfoCopyWith<GlassesDeviceInfo> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $GlassesDeviceInfoCopyWith<$Res> {
  factory $GlassesDeviceInfoCopyWith(
    GlassesDeviceInfo value,
    $Res Function(GlassesDeviceInfo) then,
  ) = _$GlassesDeviceInfoCopyWithImpl<$Res, GlassesDeviceInfo>;
  @useResult
  $Res call({
    String deviceId,
    String name,
    String? modelNumber,
    String manufacturer,
    String? firmwareVersion,
    String? hardwareVersion,
    String? serialNumber,
    double batteryLevel,
    BatteryStatus batteryStatus,
    bool isCharging,
    int rssi,
    SignalStrength signalStrength,
    DeviceHealth health,
    bool isConnected,
    DateTime? lastSeen,
    GlassesCapabilities capabilities,
    GlassesConfiguration configuration,
    Map<String, dynamic> metadata,
  });

  $GlassesCapabilitiesCopyWith<$Res> get capabilities;
  $GlassesConfigurationCopyWith<$Res> get configuration;
}

/// @nodoc
class _$GlassesDeviceInfoCopyWithImpl<$Res, $Val extends GlassesDeviceInfo>
    implements $GlassesDeviceInfoCopyWith<$Res> {
  _$GlassesDeviceInfoCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of GlassesDeviceInfo
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? deviceId = null,
    Object? name = null,
    Object? modelNumber = freezed,
    Object? manufacturer = null,
    Object? firmwareVersion = freezed,
    Object? hardwareVersion = freezed,
    Object? serialNumber = freezed,
    Object? batteryLevel = null,
    Object? batteryStatus = null,
    Object? isCharging = null,
    Object? rssi = null,
    Object? signalStrength = null,
    Object? health = null,
    Object? isConnected = null,
    Object? lastSeen = freezed,
    Object? capabilities = null,
    Object? configuration = null,
    Object? metadata = null,
  }) {
    return _then(
      _value.copyWith(
            deviceId:
                null == deviceId
                    ? _value.deviceId
                    : deviceId // ignore: cast_nullable_to_non_nullable
                        as String,
            name:
                null == name
                    ? _value.name
                    : name // ignore: cast_nullable_to_non_nullable
                        as String,
            modelNumber:
                freezed == modelNumber
                    ? _value.modelNumber
                    : modelNumber // ignore: cast_nullable_to_non_nullable
                        as String?,
            manufacturer:
                null == manufacturer
                    ? _value.manufacturer
                    : manufacturer // ignore: cast_nullable_to_non_nullable
                        as String,
            firmwareVersion:
                freezed == firmwareVersion
                    ? _value.firmwareVersion
                    : firmwareVersion // ignore: cast_nullable_to_non_nullable
                        as String?,
            hardwareVersion:
                freezed == hardwareVersion
                    ? _value.hardwareVersion
                    : hardwareVersion // ignore: cast_nullable_to_non_nullable
                        as String?,
            serialNumber:
                freezed == serialNumber
                    ? _value.serialNumber
                    : serialNumber // ignore: cast_nullable_to_non_nullable
                        as String?,
            batteryLevel:
                null == batteryLevel
                    ? _value.batteryLevel
                    : batteryLevel // ignore: cast_nullable_to_non_nullable
                        as double,
            batteryStatus:
                null == batteryStatus
                    ? _value.batteryStatus
                    : batteryStatus // ignore: cast_nullable_to_non_nullable
                        as BatteryStatus,
            isCharging:
                null == isCharging
                    ? _value.isCharging
                    : isCharging // ignore: cast_nullable_to_non_nullable
                        as bool,
            rssi:
                null == rssi
                    ? _value.rssi
                    : rssi // ignore: cast_nullable_to_non_nullable
                        as int,
            signalStrength:
                null == signalStrength
                    ? _value.signalStrength
                    : signalStrength // ignore: cast_nullable_to_non_nullable
                        as SignalStrength,
            health:
                null == health
                    ? _value.health
                    : health // ignore: cast_nullable_to_non_nullable
                        as DeviceHealth,
            isConnected:
                null == isConnected
                    ? _value.isConnected
                    : isConnected // ignore: cast_nullable_to_non_nullable
                        as bool,
            lastSeen:
                freezed == lastSeen
                    ? _value.lastSeen
                    : lastSeen // ignore: cast_nullable_to_non_nullable
                        as DateTime?,
            capabilities:
                null == capabilities
                    ? _value.capabilities
                    : capabilities // ignore: cast_nullable_to_non_nullable
                        as GlassesCapabilities,
            configuration:
                null == configuration
                    ? _value.configuration
                    : configuration // ignore: cast_nullable_to_non_nullable
                        as GlassesConfiguration,
            metadata:
                null == metadata
                    ? _value.metadata
                    : metadata // ignore: cast_nullable_to_non_nullable
                        as Map<String, dynamic>,
          )
          as $Val,
    );
  }

  /// Create a copy of GlassesDeviceInfo
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $GlassesCapabilitiesCopyWith<$Res> get capabilities {
    return $GlassesCapabilitiesCopyWith<$Res>(_value.capabilities, (value) {
      return _then(_value.copyWith(capabilities: value) as $Val);
    });
  }

  /// Create a copy of GlassesDeviceInfo
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $GlassesConfigurationCopyWith<$Res> get configuration {
    return $GlassesConfigurationCopyWith<$Res>(_value.configuration, (value) {
      return _then(_value.copyWith(configuration: value) as $Val);
    });
  }
}

/// @nodoc
abstract class _$$GlassesDeviceInfoImplCopyWith<$Res>
    implements $GlassesDeviceInfoCopyWith<$Res> {
  factory _$$GlassesDeviceInfoImplCopyWith(
    _$GlassesDeviceInfoImpl value,
    $Res Function(_$GlassesDeviceInfoImpl) then,
  ) = __$$GlassesDeviceInfoImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String deviceId,
    String name,
    String? modelNumber,
    String manufacturer,
    String? firmwareVersion,
    String? hardwareVersion,
    String? serialNumber,
    double batteryLevel,
    BatteryStatus batteryStatus,
    bool isCharging,
    int rssi,
    SignalStrength signalStrength,
    DeviceHealth health,
    bool isConnected,
    DateTime? lastSeen,
    GlassesCapabilities capabilities,
    GlassesConfiguration configuration,
    Map<String, dynamic> metadata,
  });

  @override
  $GlassesCapabilitiesCopyWith<$Res> get capabilities;
  @override
  $GlassesConfigurationCopyWith<$Res> get configuration;
}

/// @nodoc
class __$$GlassesDeviceInfoImplCopyWithImpl<$Res>
    extends _$GlassesDeviceInfoCopyWithImpl<$Res, _$GlassesDeviceInfoImpl>
    implements _$$GlassesDeviceInfoImplCopyWith<$Res> {
  __$$GlassesDeviceInfoImplCopyWithImpl(
    _$GlassesDeviceInfoImpl _value,
    $Res Function(_$GlassesDeviceInfoImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of GlassesDeviceInfo
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? deviceId = null,
    Object? name = null,
    Object? modelNumber = freezed,
    Object? manufacturer = null,
    Object? firmwareVersion = freezed,
    Object? hardwareVersion = freezed,
    Object? serialNumber = freezed,
    Object? batteryLevel = null,
    Object? batteryStatus = null,
    Object? isCharging = null,
    Object? rssi = null,
    Object? signalStrength = null,
    Object? health = null,
    Object? isConnected = null,
    Object? lastSeen = freezed,
    Object? capabilities = null,
    Object? configuration = null,
    Object? metadata = null,
  }) {
    return _then(
      _$GlassesDeviceInfoImpl(
        deviceId:
            null == deviceId
                ? _value.deviceId
                : deviceId // ignore: cast_nullable_to_non_nullable
                    as String,
        name:
            null == name
                ? _value.name
                : name // ignore: cast_nullable_to_non_nullable
                    as String,
        modelNumber:
            freezed == modelNumber
                ? _value.modelNumber
                : modelNumber // ignore: cast_nullable_to_non_nullable
                    as String?,
        manufacturer:
            null == manufacturer
                ? _value.manufacturer
                : manufacturer // ignore: cast_nullable_to_non_nullable
                    as String,
        firmwareVersion:
            freezed == firmwareVersion
                ? _value.firmwareVersion
                : firmwareVersion // ignore: cast_nullable_to_non_nullable
                    as String?,
        hardwareVersion:
            freezed == hardwareVersion
                ? _value.hardwareVersion
                : hardwareVersion // ignore: cast_nullable_to_non_nullable
                    as String?,
        serialNumber:
            freezed == serialNumber
                ? _value.serialNumber
                : serialNumber // ignore: cast_nullable_to_non_nullable
                    as String?,
        batteryLevel:
            null == batteryLevel
                ? _value.batteryLevel
                : batteryLevel // ignore: cast_nullable_to_non_nullable
                    as double,
        batteryStatus:
            null == batteryStatus
                ? _value.batteryStatus
                : batteryStatus // ignore: cast_nullable_to_non_nullable
                    as BatteryStatus,
        isCharging:
            null == isCharging
                ? _value.isCharging
                : isCharging // ignore: cast_nullable_to_non_nullable
                    as bool,
        rssi:
            null == rssi
                ? _value.rssi
                : rssi // ignore: cast_nullable_to_non_nullable
                    as int,
        signalStrength:
            null == signalStrength
                ? _value.signalStrength
                : signalStrength // ignore: cast_nullable_to_non_nullable
                    as SignalStrength,
        health:
            null == health
                ? _value.health
                : health // ignore: cast_nullable_to_non_nullable
                    as DeviceHealth,
        isConnected:
            null == isConnected
                ? _value.isConnected
                : isConnected // ignore: cast_nullable_to_non_nullable
                    as bool,
        lastSeen:
            freezed == lastSeen
                ? _value.lastSeen
                : lastSeen // ignore: cast_nullable_to_non_nullable
                    as DateTime?,
        capabilities:
            null == capabilities
                ? _value.capabilities
                : capabilities // ignore: cast_nullable_to_non_nullable
                    as GlassesCapabilities,
        configuration:
            null == configuration
                ? _value.configuration
                : configuration // ignore: cast_nullable_to_non_nullable
                    as GlassesConfiguration,
        metadata:
            null == metadata
                ? _value._metadata
                : metadata // ignore: cast_nullable_to_non_nullable
                    as Map<String, dynamic>,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$GlassesDeviceInfoImpl extends _GlassesDeviceInfo {
  const _$GlassesDeviceInfoImpl({
    required this.deviceId,
    required this.name,
    this.modelNumber,
    this.manufacturer = 'Even Realities',
    this.firmwareVersion,
    this.hardwareVersion,
    this.serialNumber,
    this.batteryLevel = 0.0,
    this.batteryStatus = BatteryStatus.unknown,
    this.isCharging = false,
    this.rssi = -100,
    this.signalStrength = SignalStrength.unknown,
    this.health = DeviceHealth.unknown,
    this.isConnected = false,
    this.lastSeen,
    this.capabilities = const GlassesCapabilities(),
    this.configuration = const GlassesConfiguration(),
    final Map<String, dynamic> metadata = const {},
  }) : _metadata = metadata,
       super._();

  factory _$GlassesDeviceInfoImpl.fromJson(Map<String, dynamic> json) =>
      _$$GlassesDeviceInfoImplFromJson(json);

  /// Unique device identifier
  @override
  final String deviceId;

  /// Device name as advertised
  @override
  final String name;

  /// Model number
  @override
  final String? modelNumber;

  /// Manufacturer name
  @override
  @JsonKey()
  final String manufacturer;

  /// Firmware version
  @override
  final String? firmwareVersion;

  /// Hardware version
  @override
  final String? hardwareVersion;

  /// Serial number
  @override
  final String? serialNumber;

  /// Battery level (0.0 to 1.0)
  @override
  @JsonKey()
  final double batteryLevel;

  /// Battery status
  @override
  @JsonKey()
  final BatteryStatus batteryStatus;

  /// Whether device is charging
  @override
  @JsonKey()
  final bool isCharging;

  /// Signal strength (RSSI)
  @override
  @JsonKey()
  final int rssi;

  /// Signal strength category
  @override
  @JsonKey()
  final SignalStrength signalStrength;

  /// Device health status
  @override
  @JsonKey()
  final DeviceHealth health;

  /// Whether device is currently connected
  @override
  @JsonKey()
  final bool isConnected;

  /// Last seen timestamp
  @override
  final DateTime? lastSeen;

  /// Device capabilities
  @override
  @JsonKey()
  final GlassesCapabilities capabilities;

  /// Device configuration
  @override
  @JsonKey()
  final GlassesConfiguration configuration;

  /// Additional device metadata
  final Map<String, dynamic> _metadata;

  /// Additional device metadata
  @override
  @JsonKey()
  Map<String, dynamic> get metadata {
    if (_metadata is EqualUnmodifiableMapView) return _metadata;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(_metadata);
  }

  @override
  String toString() {
    return 'GlassesDeviceInfo(deviceId: $deviceId, name: $name, modelNumber: $modelNumber, manufacturer: $manufacturer, firmwareVersion: $firmwareVersion, hardwareVersion: $hardwareVersion, serialNumber: $serialNumber, batteryLevel: $batteryLevel, batteryStatus: $batteryStatus, isCharging: $isCharging, rssi: $rssi, signalStrength: $signalStrength, health: $health, isConnected: $isConnected, lastSeen: $lastSeen, capabilities: $capabilities, configuration: $configuration, metadata: $metadata)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$GlassesDeviceInfoImpl &&
            (identical(other.deviceId, deviceId) ||
                other.deviceId == deviceId) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.modelNumber, modelNumber) ||
                other.modelNumber == modelNumber) &&
            (identical(other.manufacturer, manufacturer) ||
                other.manufacturer == manufacturer) &&
            (identical(other.firmwareVersion, firmwareVersion) ||
                other.firmwareVersion == firmwareVersion) &&
            (identical(other.hardwareVersion, hardwareVersion) ||
                other.hardwareVersion == hardwareVersion) &&
            (identical(other.serialNumber, serialNumber) ||
                other.serialNumber == serialNumber) &&
            (identical(other.batteryLevel, batteryLevel) ||
                other.batteryLevel == batteryLevel) &&
            (identical(other.batteryStatus, batteryStatus) ||
                other.batteryStatus == batteryStatus) &&
            (identical(other.isCharging, isCharging) ||
                other.isCharging == isCharging) &&
            (identical(other.rssi, rssi) || other.rssi == rssi) &&
            (identical(other.signalStrength, signalStrength) ||
                other.signalStrength == signalStrength) &&
            (identical(other.health, health) || other.health == health) &&
            (identical(other.isConnected, isConnected) ||
                other.isConnected == isConnected) &&
            (identical(other.lastSeen, lastSeen) ||
                other.lastSeen == lastSeen) &&
            (identical(other.capabilities, capabilities) ||
                other.capabilities == capabilities) &&
            (identical(other.configuration, configuration) ||
                other.configuration == configuration) &&
            const DeepCollectionEquality().equals(other._metadata, _metadata));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    deviceId,
    name,
    modelNumber,
    manufacturer,
    firmwareVersion,
    hardwareVersion,
    serialNumber,
    batteryLevel,
    batteryStatus,
    isCharging,
    rssi,
    signalStrength,
    health,
    isConnected,
    lastSeen,
    capabilities,
    configuration,
    const DeepCollectionEquality().hash(_metadata),
  );

  /// Create a copy of GlassesDeviceInfo
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$GlassesDeviceInfoImplCopyWith<_$GlassesDeviceInfoImpl> get copyWith =>
      __$$GlassesDeviceInfoImplCopyWithImpl<_$GlassesDeviceInfoImpl>(
        this,
        _$identity,
      );

  @override
  Map<String, dynamic> toJson() {
    return _$$GlassesDeviceInfoImplToJson(this);
  }
}

abstract class _GlassesDeviceInfo extends GlassesDeviceInfo {
  const factory _GlassesDeviceInfo({
    required final String deviceId,
    required final String name,
    final String? modelNumber,
    final String manufacturer,
    final String? firmwareVersion,
    final String? hardwareVersion,
    final String? serialNumber,
    final double batteryLevel,
    final BatteryStatus batteryStatus,
    final bool isCharging,
    final int rssi,
    final SignalStrength signalStrength,
    final DeviceHealth health,
    final bool isConnected,
    final DateTime? lastSeen,
    final GlassesCapabilities capabilities,
    final GlassesConfiguration configuration,
    final Map<String, dynamic> metadata,
  }) = _$GlassesDeviceInfoImpl;
  const _GlassesDeviceInfo._() : super._();

  factory _GlassesDeviceInfo.fromJson(Map<String, dynamic> json) =
      _$GlassesDeviceInfoImpl.fromJson;

  /// Unique device identifier
  @override
  String get deviceId;

  /// Device name as advertised
  @override
  String get name;

  /// Model number
  @override
  String? get modelNumber;

  /// Manufacturer name
  @override
  String get manufacturer;

  /// Firmware version
  @override
  String? get firmwareVersion;

  /// Hardware version
  @override
  String? get hardwareVersion;

  /// Serial number
  @override
  String? get serialNumber;

  /// Battery level (0.0 to 1.0)
  @override
  double get batteryLevel;

  /// Battery status
  @override
  BatteryStatus get batteryStatus;

  /// Whether device is charging
  @override
  bool get isCharging;

  /// Signal strength (RSSI)
  @override
  int get rssi;

  /// Signal strength category
  @override
  SignalStrength get signalStrength;

  /// Device health status
  @override
  DeviceHealth get health;

  /// Whether device is currently connected
  @override
  bool get isConnected;

  /// Last seen timestamp
  @override
  DateTime? get lastSeen;

  /// Device capabilities
  @override
  GlassesCapabilities get capabilities;

  /// Device configuration
  @override
  GlassesConfiguration get configuration;

  /// Additional device metadata
  @override
  Map<String, dynamic> get metadata;

  /// Create a copy of GlassesDeviceInfo
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$GlassesDeviceInfoImplCopyWith<_$GlassesDeviceInfoImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

ConnectionQuality _$ConnectionQualityFromJson(Map<String, dynamic> json) {
  return _ConnectionQuality.fromJson(json);
}

/// @nodoc
mixin _$ConnectionQuality {
  /// Signal strength
  SignalStrength get signalStrength => throw _privateConstructorUsedError;

  /// Raw RSSI value
  int get rssi => throw _privateConstructorUsedError;

  /// Connection stability score (0.0 to 1.0)
  double get stabilityScore => throw _privateConstructorUsedError;

  /// Packet loss percentage
  double get packetLoss => throw _privateConstructorUsedError;

  /// Average latency in milliseconds
  int get latencyMs => throw _privateConstructorUsedError;

  /// Number of disconnections in last hour
  int get recentDisconnections => throw _privateConstructorUsedError;

  /// Data transfer rate (bytes/second)
  int get dataRate => throw _privateConstructorUsedError;

  /// Quality assessment timestamp
  DateTime get timestamp => throw _privateConstructorUsedError;

  /// Serializes this ConnectionQuality to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of ConnectionQuality
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $ConnectionQualityCopyWith<ConnectionQuality> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $ConnectionQualityCopyWith<$Res> {
  factory $ConnectionQualityCopyWith(
    ConnectionQuality value,
    $Res Function(ConnectionQuality) then,
  ) = _$ConnectionQualityCopyWithImpl<$Res, ConnectionQuality>;
  @useResult
  $Res call({
    SignalStrength signalStrength,
    int rssi,
    double stabilityScore,
    double packetLoss,
    int latencyMs,
    int recentDisconnections,
    int dataRate,
    DateTime timestamp,
  });
}

/// @nodoc
class _$ConnectionQualityCopyWithImpl<$Res, $Val extends ConnectionQuality>
    implements $ConnectionQualityCopyWith<$Res> {
  _$ConnectionQualityCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of ConnectionQuality
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? signalStrength = null,
    Object? rssi = null,
    Object? stabilityScore = null,
    Object? packetLoss = null,
    Object? latencyMs = null,
    Object? recentDisconnections = null,
    Object? dataRate = null,
    Object? timestamp = null,
  }) {
    return _then(
      _value.copyWith(
            signalStrength:
                null == signalStrength
                    ? _value.signalStrength
                    : signalStrength // ignore: cast_nullable_to_non_nullable
                        as SignalStrength,
            rssi:
                null == rssi
                    ? _value.rssi
                    : rssi // ignore: cast_nullable_to_non_nullable
                        as int,
            stabilityScore:
                null == stabilityScore
                    ? _value.stabilityScore
                    : stabilityScore // ignore: cast_nullable_to_non_nullable
                        as double,
            packetLoss:
                null == packetLoss
                    ? _value.packetLoss
                    : packetLoss // ignore: cast_nullable_to_non_nullable
                        as double,
            latencyMs:
                null == latencyMs
                    ? _value.latencyMs
                    : latencyMs // ignore: cast_nullable_to_non_nullable
                        as int,
            recentDisconnections:
                null == recentDisconnections
                    ? _value.recentDisconnections
                    : recentDisconnections // ignore: cast_nullable_to_non_nullable
                        as int,
            dataRate:
                null == dataRate
                    ? _value.dataRate
                    : dataRate // ignore: cast_nullable_to_non_nullable
                        as int,
            timestamp:
                null == timestamp
                    ? _value.timestamp
                    : timestamp // ignore: cast_nullable_to_non_nullable
                        as DateTime,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$ConnectionQualityImplCopyWith<$Res>
    implements $ConnectionQualityCopyWith<$Res> {
  factory _$$ConnectionQualityImplCopyWith(
    _$ConnectionQualityImpl value,
    $Res Function(_$ConnectionQualityImpl) then,
  ) = __$$ConnectionQualityImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    SignalStrength signalStrength,
    int rssi,
    double stabilityScore,
    double packetLoss,
    int latencyMs,
    int recentDisconnections,
    int dataRate,
    DateTime timestamp,
  });
}

/// @nodoc
class __$$ConnectionQualityImplCopyWithImpl<$Res>
    extends _$ConnectionQualityCopyWithImpl<$Res, _$ConnectionQualityImpl>
    implements _$$ConnectionQualityImplCopyWith<$Res> {
  __$$ConnectionQualityImplCopyWithImpl(
    _$ConnectionQualityImpl _value,
    $Res Function(_$ConnectionQualityImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of ConnectionQuality
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? signalStrength = null,
    Object? rssi = null,
    Object? stabilityScore = null,
    Object? packetLoss = null,
    Object? latencyMs = null,
    Object? recentDisconnections = null,
    Object? dataRate = null,
    Object? timestamp = null,
  }) {
    return _then(
      _$ConnectionQualityImpl(
        signalStrength:
            null == signalStrength
                ? _value.signalStrength
                : signalStrength // ignore: cast_nullable_to_non_nullable
                    as SignalStrength,
        rssi:
            null == rssi
                ? _value.rssi
                : rssi // ignore: cast_nullable_to_non_nullable
                    as int,
        stabilityScore:
            null == stabilityScore
                ? _value.stabilityScore
                : stabilityScore // ignore: cast_nullable_to_non_nullable
                    as double,
        packetLoss:
            null == packetLoss
                ? _value.packetLoss
                : packetLoss // ignore: cast_nullable_to_non_nullable
                    as double,
        latencyMs:
            null == latencyMs
                ? _value.latencyMs
                : latencyMs // ignore: cast_nullable_to_non_nullable
                    as int,
        recentDisconnections:
            null == recentDisconnections
                ? _value.recentDisconnections
                : recentDisconnections // ignore: cast_nullable_to_non_nullable
                    as int,
        dataRate:
            null == dataRate
                ? _value.dataRate
                : dataRate // ignore: cast_nullable_to_non_nullable
                    as int,
        timestamp:
            null == timestamp
                ? _value.timestamp
                : timestamp // ignore: cast_nullable_to_non_nullable
                    as DateTime,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$ConnectionQualityImpl extends _ConnectionQuality {
  const _$ConnectionQualityImpl({
    this.signalStrength = SignalStrength.unknown,
    this.rssi = -100,
    this.stabilityScore = 0.0,
    this.packetLoss = 0.0,
    this.latencyMs = 0,
    this.recentDisconnections = 0,
    this.dataRate = 0,
    required this.timestamp,
  }) : super._();

  factory _$ConnectionQualityImpl.fromJson(Map<String, dynamic> json) =>
      _$$ConnectionQualityImplFromJson(json);

  /// Signal strength
  @override
  @JsonKey()
  final SignalStrength signalStrength;

  /// Raw RSSI value
  @override
  @JsonKey()
  final int rssi;

  /// Connection stability score (0.0 to 1.0)
  @override
  @JsonKey()
  final double stabilityScore;

  /// Packet loss percentage
  @override
  @JsonKey()
  final double packetLoss;

  /// Average latency in milliseconds
  @override
  @JsonKey()
  final int latencyMs;

  /// Number of disconnections in last hour
  @override
  @JsonKey()
  final int recentDisconnections;

  /// Data transfer rate (bytes/second)
  @override
  @JsonKey()
  final int dataRate;

  /// Quality assessment timestamp
  @override
  final DateTime timestamp;

  @override
  String toString() {
    return 'ConnectionQuality(signalStrength: $signalStrength, rssi: $rssi, stabilityScore: $stabilityScore, packetLoss: $packetLoss, latencyMs: $latencyMs, recentDisconnections: $recentDisconnections, dataRate: $dataRate, timestamp: $timestamp)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ConnectionQualityImpl &&
            (identical(other.signalStrength, signalStrength) ||
                other.signalStrength == signalStrength) &&
            (identical(other.rssi, rssi) || other.rssi == rssi) &&
            (identical(other.stabilityScore, stabilityScore) ||
                other.stabilityScore == stabilityScore) &&
            (identical(other.packetLoss, packetLoss) ||
                other.packetLoss == packetLoss) &&
            (identical(other.latencyMs, latencyMs) ||
                other.latencyMs == latencyMs) &&
            (identical(other.recentDisconnections, recentDisconnections) ||
                other.recentDisconnections == recentDisconnections) &&
            (identical(other.dataRate, dataRate) ||
                other.dataRate == dataRate) &&
            (identical(other.timestamp, timestamp) ||
                other.timestamp == timestamp));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    signalStrength,
    rssi,
    stabilityScore,
    packetLoss,
    latencyMs,
    recentDisconnections,
    dataRate,
    timestamp,
  );

  /// Create a copy of ConnectionQuality
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$ConnectionQualityImplCopyWith<_$ConnectionQualityImpl> get copyWith =>
      __$$ConnectionQualityImplCopyWithImpl<_$ConnectionQualityImpl>(
        this,
        _$identity,
      );

  @override
  Map<String, dynamic> toJson() {
    return _$$ConnectionQualityImplToJson(this);
  }
}

abstract class _ConnectionQuality extends ConnectionQuality {
  const factory _ConnectionQuality({
    final SignalStrength signalStrength,
    final int rssi,
    final double stabilityScore,
    final double packetLoss,
    final int latencyMs,
    final int recentDisconnections,
    final int dataRate,
    required final DateTime timestamp,
  }) = _$ConnectionQualityImpl;
  const _ConnectionQuality._() : super._();

  factory _ConnectionQuality.fromJson(Map<String, dynamic> json) =
      _$ConnectionQualityImpl.fromJson;

  /// Signal strength
  @override
  SignalStrength get signalStrength;

  /// Raw RSSI value
  @override
  int get rssi;

  /// Connection stability score (0.0 to 1.0)
  @override
  double get stabilityScore;

  /// Packet loss percentage
  @override
  double get packetLoss;

  /// Average latency in milliseconds
  @override
  int get latencyMs;

  /// Number of disconnections in last hour
  @override
  int get recentDisconnections;

  /// Data transfer rate (bytes/second)
  @override
  int get dataRate;

  /// Quality assessment timestamp
  @override
  DateTime get timestamp;

  /// Create a copy of ConnectionQuality
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$ConnectionQualityImplCopyWith<_$ConnectionQualityImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

HUDDisplayState _$HUDDisplayStateFromJson(Map<String, dynamic> json) {
  return _HUDDisplayState.fromJson(json);
}

/// @nodoc
mixin _$HUDDisplayState {
  /// Whether HUD is currently active
  bool get isActive => throw _privateConstructorUsedError;

  /// Current brightness level (0.0 to 1.0)
  double get brightness => throw _privateConstructorUsedError;

  /// Currently displayed content
  String? get currentContent => throw _privateConstructorUsedError;

  /// Content type being displayed
  HUDContentType? get contentType => throw _privateConstructorUsedError;

  /// Display position
  HUDPosition get position => throw _privateConstructorUsedError;

  /// Display style settings
  HUDStyleSettings get style => throw _privateConstructorUsedError;

  /// Whether display is temporarily paused
  bool get isPaused => throw _privateConstructorUsedError;

  /// Last update timestamp
  DateTime? get lastUpdate => throw _privateConstructorUsedError;

  /// Display queue for upcoming content
  List<HUDQueueItem> get displayQueue => throw _privateConstructorUsedError;

  /// Serializes this HUDDisplayState to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of HUDDisplayState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $HUDDisplayStateCopyWith<HUDDisplayState> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $HUDDisplayStateCopyWith<$Res> {
  factory $HUDDisplayStateCopyWith(
    HUDDisplayState value,
    $Res Function(HUDDisplayState) then,
  ) = _$HUDDisplayStateCopyWithImpl<$Res, HUDDisplayState>;
  @useResult
  $Res call({
    bool isActive,
    double brightness,
    String? currentContent,
    HUDContentType? contentType,
    HUDPosition position,
    HUDStyleSettings style,
    bool isPaused,
    DateTime? lastUpdate,
    List<HUDQueueItem> displayQueue,
  });

  $HUDStyleSettingsCopyWith<$Res> get style;
}

/// @nodoc
class _$HUDDisplayStateCopyWithImpl<$Res, $Val extends HUDDisplayState>
    implements $HUDDisplayStateCopyWith<$Res> {
  _$HUDDisplayStateCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of HUDDisplayState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? isActive = null,
    Object? brightness = null,
    Object? currentContent = freezed,
    Object? contentType = freezed,
    Object? position = null,
    Object? style = null,
    Object? isPaused = null,
    Object? lastUpdate = freezed,
    Object? displayQueue = null,
  }) {
    return _then(
      _value.copyWith(
            isActive:
                null == isActive
                    ? _value.isActive
                    : isActive // ignore: cast_nullable_to_non_nullable
                        as bool,
            brightness:
                null == brightness
                    ? _value.brightness
                    : brightness // ignore: cast_nullable_to_non_nullable
                        as double,
            currentContent:
                freezed == currentContent
                    ? _value.currentContent
                    : currentContent // ignore: cast_nullable_to_non_nullable
                        as String?,
            contentType:
                freezed == contentType
                    ? _value.contentType
                    : contentType // ignore: cast_nullable_to_non_nullable
                        as HUDContentType?,
            position:
                null == position
                    ? _value.position
                    : position // ignore: cast_nullable_to_non_nullable
                        as HUDPosition,
            style:
                null == style
                    ? _value.style
                    : style // ignore: cast_nullable_to_non_nullable
                        as HUDStyleSettings,
            isPaused:
                null == isPaused
                    ? _value.isPaused
                    : isPaused // ignore: cast_nullable_to_non_nullable
                        as bool,
            lastUpdate:
                freezed == lastUpdate
                    ? _value.lastUpdate
                    : lastUpdate // ignore: cast_nullable_to_non_nullable
                        as DateTime?,
            displayQueue:
                null == displayQueue
                    ? _value.displayQueue
                    : displayQueue // ignore: cast_nullable_to_non_nullable
                        as List<HUDQueueItem>,
          )
          as $Val,
    );
  }

  /// Create a copy of HUDDisplayState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $HUDStyleSettingsCopyWith<$Res> get style {
    return $HUDStyleSettingsCopyWith<$Res>(_value.style, (value) {
      return _then(_value.copyWith(style: value) as $Val);
    });
  }
}

/// @nodoc
abstract class _$$HUDDisplayStateImplCopyWith<$Res>
    implements $HUDDisplayStateCopyWith<$Res> {
  factory _$$HUDDisplayStateImplCopyWith(
    _$HUDDisplayStateImpl value,
    $Res Function(_$HUDDisplayStateImpl) then,
  ) = __$$HUDDisplayStateImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    bool isActive,
    double brightness,
    String? currentContent,
    HUDContentType? contentType,
    HUDPosition position,
    HUDStyleSettings style,
    bool isPaused,
    DateTime? lastUpdate,
    List<HUDQueueItem> displayQueue,
  });

  @override
  $HUDStyleSettingsCopyWith<$Res> get style;
}

/// @nodoc
class __$$HUDDisplayStateImplCopyWithImpl<$Res>
    extends _$HUDDisplayStateCopyWithImpl<$Res, _$HUDDisplayStateImpl>
    implements _$$HUDDisplayStateImplCopyWith<$Res> {
  __$$HUDDisplayStateImplCopyWithImpl(
    _$HUDDisplayStateImpl _value,
    $Res Function(_$HUDDisplayStateImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of HUDDisplayState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? isActive = null,
    Object? brightness = null,
    Object? currentContent = freezed,
    Object? contentType = freezed,
    Object? position = null,
    Object? style = null,
    Object? isPaused = null,
    Object? lastUpdate = freezed,
    Object? displayQueue = null,
  }) {
    return _then(
      _$HUDDisplayStateImpl(
        isActive:
            null == isActive
                ? _value.isActive
                : isActive // ignore: cast_nullable_to_non_nullable
                    as bool,
        brightness:
            null == brightness
                ? _value.brightness
                : brightness // ignore: cast_nullable_to_non_nullable
                    as double,
        currentContent:
            freezed == currentContent
                ? _value.currentContent
                : currentContent // ignore: cast_nullable_to_non_nullable
                    as String?,
        contentType:
            freezed == contentType
                ? _value.contentType
                : contentType // ignore: cast_nullable_to_non_nullable
                    as HUDContentType?,
        position:
            null == position
                ? _value.position
                : position // ignore: cast_nullable_to_non_nullable
                    as HUDPosition,
        style:
            null == style
                ? _value.style
                : style // ignore: cast_nullable_to_non_nullable
                    as HUDStyleSettings,
        isPaused:
            null == isPaused
                ? _value.isPaused
                : isPaused // ignore: cast_nullable_to_non_nullable
                    as bool,
        lastUpdate:
            freezed == lastUpdate
                ? _value.lastUpdate
                : lastUpdate // ignore: cast_nullable_to_non_nullable
                    as DateTime?,
        displayQueue:
            null == displayQueue
                ? _value._displayQueue
                : displayQueue // ignore: cast_nullable_to_non_nullable
                    as List<HUDQueueItem>,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$HUDDisplayStateImpl extends _HUDDisplayState {
  const _$HUDDisplayStateImpl({
    this.isActive = false,
    this.brightness = 0.8,
    this.currentContent,
    this.contentType,
    this.position = HUDPosition.center,
    this.style = const HUDStyleSettings(),
    this.isPaused = false,
    this.lastUpdate,
    final List<HUDQueueItem> displayQueue = const [],
  }) : _displayQueue = displayQueue,
       super._();

  factory _$HUDDisplayStateImpl.fromJson(Map<String, dynamic> json) =>
      _$$HUDDisplayStateImplFromJson(json);

  /// Whether HUD is currently active
  @override
  @JsonKey()
  final bool isActive;

  /// Current brightness level (0.0 to 1.0)
  @override
  @JsonKey()
  final double brightness;

  /// Currently displayed content
  @override
  final String? currentContent;

  /// Content type being displayed
  @override
  final HUDContentType? contentType;

  /// Display position
  @override
  @JsonKey()
  final HUDPosition position;

  /// Display style settings
  @override
  @JsonKey()
  final HUDStyleSettings style;

  /// Whether display is temporarily paused
  @override
  @JsonKey()
  final bool isPaused;

  /// Last update timestamp
  @override
  final DateTime? lastUpdate;

  /// Display queue for upcoming content
  final List<HUDQueueItem> _displayQueue;

  /// Display queue for upcoming content
  @override
  @JsonKey()
  List<HUDQueueItem> get displayQueue {
    if (_displayQueue is EqualUnmodifiableListView) return _displayQueue;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_displayQueue);
  }

  @override
  String toString() {
    return 'HUDDisplayState(isActive: $isActive, brightness: $brightness, currentContent: $currentContent, contentType: $contentType, position: $position, style: $style, isPaused: $isPaused, lastUpdate: $lastUpdate, displayQueue: $displayQueue)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$HUDDisplayStateImpl &&
            (identical(other.isActive, isActive) ||
                other.isActive == isActive) &&
            (identical(other.brightness, brightness) ||
                other.brightness == brightness) &&
            (identical(other.currentContent, currentContent) ||
                other.currentContent == currentContent) &&
            (identical(other.contentType, contentType) ||
                other.contentType == contentType) &&
            (identical(other.position, position) ||
                other.position == position) &&
            (identical(other.style, style) || other.style == style) &&
            (identical(other.isPaused, isPaused) ||
                other.isPaused == isPaused) &&
            (identical(other.lastUpdate, lastUpdate) ||
                other.lastUpdate == lastUpdate) &&
            const DeepCollectionEquality().equals(
              other._displayQueue,
              _displayQueue,
            ));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    isActive,
    brightness,
    currentContent,
    contentType,
    position,
    style,
    isPaused,
    lastUpdate,
    const DeepCollectionEquality().hash(_displayQueue),
  );

  /// Create a copy of HUDDisplayState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$HUDDisplayStateImplCopyWith<_$HUDDisplayStateImpl> get copyWith =>
      __$$HUDDisplayStateImplCopyWithImpl<_$HUDDisplayStateImpl>(
        this,
        _$identity,
      );

  @override
  Map<String, dynamic> toJson() {
    return _$$HUDDisplayStateImplToJson(this);
  }
}

abstract class _HUDDisplayState extends HUDDisplayState {
  const factory _HUDDisplayState({
    final bool isActive,
    final double brightness,
    final String? currentContent,
    final HUDContentType? contentType,
    final HUDPosition position,
    final HUDStyleSettings style,
    final bool isPaused,
    final DateTime? lastUpdate,
    final List<HUDQueueItem> displayQueue,
  }) = _$HUDDisplayStateImpl;
  const _HUDDisplayState._() : super._();

  factory _HUDDisplayState.fromJson(Map<String, dynamic> json) =
      _$HUDDisplayStateImpl.fromJson;

  /// Whether HUD is currently active
  @override
  bool get isActive;

  /// Current brightness level (0.0 to 1.0)
  @override
  double get brightness;

  /// Currently displayed content
  @override
  String? get currentContent;

  /// Content type being displayed
  @override
  HUDContentType? get contentType;

  /// Display position
  @override
  HUDPosition get position;

  /// Display style settings
  @override
  HUDStyleSettings get style;

  /// Whether display is temporarily paused
  @override
  bool get isPaused;

  /// Last update timestamp
  @override
  DateTime? get lastUpdate;

  /// Display queue for upcoming content
  @override
  List<HUDQueueItem> get displayQueue;

  /// Create a copy of HUDDisplayState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$HUDDisplayStateImplCopyWith<_$HUDDisplayStateImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

HUDStyleSettings _$HUDStyleSettingsFromJson(Map<String, dynamic> json) {
  return _HUDStyleSettings.fromJson(json);
}

/// @nodoc
mixin _$HUDStyleSettings {
  /// Font size
  double get fontSize => throw _privateConstructorUsedError;

  /// Text color
  String get textColor => throw _privateConstructorUsedError;

  /// Background color
  String get backgroundColor => throw _privateConstructorUsedError;

  /// Font weight
  String get fontWeight => throw _privateConstructorUsedError;

  /// Text alignment
  String get alignment => throw _privateConstructorUsedError;

  /// Display duration in seconds
  int get displayDuration => throw _privateConstructorUsedError;

  /// Animation type
  String get animation => throw _privateConstructorUsedError;

  /// Serializes this HUDStyleSettings to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of HUDStyleSettings
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $HUDStyleSettingsCopyWith<HUDStyleSettings> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $HUDStyleSettingsCopyWith<$Res> {
  factory $HUDStyleSettingsCopyWith(
    HUDStyleSettings value,
    $Res Function(HUDStyleSettings) then,
  ) = _$HUDStyleSettingsCopyWithImpl<$Res, HUDStyleSettings>;
  @useResult
  $Res call({
    double fontSize,
    String textColor,
    String backgroundColor,
    String fontWeight,
    String alignment,
    int displayDuration,
    String animation,
  });
}

/// @nodoc
class _$HUDStyleSettingsCopyWithImpl<$Res, $Val extends HUDStyleSettings>
    implements $HUDStyleSettingsCopyWith<$Res> {
  _$HUDStyleSettingsCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of HUDStyleSettings
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? fontSize = null,
    Object? textColor = null,
    Object? backgroundColor = null,
    Object? fontWeight = null,
    Object? alignment = null,
    Object? displayDuration = null,
    Object? animation = null,
  }) {
    return _then(
      _value.copyWith(
            fontSize:
                null == fontSize
                    ? _value.fontSize
                    : fontSize // ignore: cast_nullable_to_non_nullable
                        as double,
            textColor:
                null == textColor
                    ? _value.textColor
                    : textColor // ignore: cast_nullable_to_non_nullable
                        as String,
            backgroundColor:
                null == backgroundColor
                    ? _value.backgroundColor
                    : backgroundColor // ignore: cast_nullable_to_non_nullable
                        as String,
            fontWeight:
                null == fontWeight
                    ? _value.fontWeight
                    : fontWeight // ignore: cast_nullable_to_non_nullable
                        as String,
            alignment:
                null == alignment
                    ? _value.alignment
                    : alignment // ignore: cast_nullable_to_non_nullable
                        as String,
            displayDuration:
                null == displayDuration
                    ? _value.displayDuration
                    : displayDuration // ignore: cast_nullable_to_non_nullable
                        as int,
            animation:
                null == animation
                    ? _value.animation
                    : animation // ignore: cast_nullable_to_non_nullable
                        as String,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$HUDStyleSettingsImplCopyWith<$Res>
    implements $HUDStyleSettingsCopyWith<$Res> {
  factory _$$HUDStyleSettingsImplCopyWith(
    _$HUDStyleSettingsImpl value,
    $Res Function(_$HUDStyleSettingsImpl) then,
  ) = __$$HUDStyleSettingsImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    double fontSize,
    String textColor,
    String backgroundColor,
    String fontWeight,
    String alignment,
    int displayDuration,
    String animation,
  });
}

/// @nodoc
class __$$HUDStyleSettingsImplCopyWithImpl<$Res>
    extends _$HUDStyleSettingsCopyWithImpl<$Res, _$HUDStyleSettingsImpl>
    implements _$$HUDStyleSettingsImplCopyWith<$Res> {
  __$$HUDStyleSettingsImplCopyWithImpl(
    _$HUDStyleSettingsImpl _value,
    $Res Function(_$HUDStyleSettingsImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of HUDStyleSettings
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? fontSize = null,
    Object? textColor = null,
    Object? backgroundColor = null,
    Object? fontWeight = null,
    Object? alignment = null,
    Object? displayDuration = null,
    Object? animation = null,
  }) {
    return _then(
      _$HUDStyleSettingsImpl(
        fontSize:
            null == fontSize
                ? _value.fontSize
                : fontSize // ignore: cast_nullable_to_non_nullable
                    as double,
        textColor:
            null == textColor
                ? _value.textColor
                : textColor // ignore: cast_nullable_to_non_nullable
                    as String,
        backgroundColor:
            null == backgroundColor
                ? _value.backgroundColor
                : backgroundColor // ignore: cast_nullable_to_non_nullable
                    as String,
        fontWeight:
            null == fontWeight
                ? _value.fontWeight
                : fontWeight // ignore: cast_nullable_to_non_nullable
                    as String,
        alignment:
            null == alignment
                ? _value.alignment
                : alignment // ignore: cast_nullable_to_non_nullable
                    as String,
        displayDuration:
            null == displayDuration
                ? _value.displayDuration
                : displayDuration // ignore: cast_nullable_to_non_nullable
                    as int,
        animation:
            null == animation
                ? _value.animation
                : animation // ignore: cast_nullable_to_non_nullable
                    as String,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$HUDStyleSettingsImpl implements _HUDStyleSettings {
  const _$HUDStyleSettingsImpl({
    this.fontSize = 16.0,
    this.textColor = '#FFFFFF',
    this.backgroundColor = '#000000',
    this.fontWeight = 'normal',
    this.alignment = 'center',
    this.displayDuration = 5,
    this.animation = 'fade',
  });

  factory _$HUDStyleSettingsImpl.fromJson(Map<String, dynamic> json) =>
      _$$HUDStyleSettingsImplFromJson(json);

  /// Font size
  @override
  @JsonKey()
  final double fontSize;

  /// Text color
  @override
  @JsonKey()
  final String textColor;

  /// Background color
  @override
  @JsonKey()
  final String backgroundColor;

  /// Font weight
  @override
  @JsonKey()
  final String fontWeight;

  /// Text alignment
  @override
  @JsonKey()
  final String alignment;

  /// Display duration in seconds
  @override
  @JsonKey()
  final int displayDuration;

  /// Animation type
  @override
  @JsonKey()
  final String animation;

  @override
  String toString() {
    return 'HUDStyleSettings(fontSize: $fontSize, textColor: $textColor, backgroundColor: $backgroundColor, fontWeight: $fontWeight, alignment: $alignment, displayDuration: $displayDuration, animation: $animation)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$HUDStyleSettingsImpl &&
            (identical(other.fontSize, fontSize) ||
                other.fontSize == fontSize) &&
            (identical(other.textColor, textColor) ||
                other.textColor == textColor) &&
            (identical(other.backgroundColor, backgroundColor) ||
                other.backgroundColor == backgroundColor) &&
            (identical(other.fontWeight, fontWeight) ||
                other.fontWeight == fontWeight) &&
            (identical(other.alignment, alignment) ||
                other.alignment == alignment) &&
            (identical(other.displayDuration, displayDuration) ||
                other.displayDuration == displayDuration) &&
            (identical(other.animation, animation) ||
                other.animation == animation));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    fontSize,
    textColor,
    backgroundColor,
    fontWeight,
    alignment,
    displayDuration,
    animation,
  );

  /// Create a copy of HUDStyleSettings
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$HUDStyleSettingsImplCopyWith<_$HUDStyleSettingsImpl> get copyWith =>
      __$$HUDStyleSettingsImplCopyWithImpl<_$HUDStyleSettingsImpl>(
        this,
        _$identity,
      );

  @override
  Map<String, dynamic> toJson() {
    return _$$HUDStyleSettingsImplToJson(this);
  }
}

abstract class _HUDStyleSettings implements HUDStyleSettings {
  const factory _HUDStyleSettings({
    final double fontSize,
    final String textColor,
    final String backgroundColor,
    final String fontWeight,
    final String alignment,
    final int displayDuration,
    final String animation,
  }) = _$HUDStyleSettingsImpl;

  factory _HUDStyleSettings.fromJson(Map<String, dynamic> json) =
      _$HUDStyleSettingsImpl.fromJson;

  /// Font size
  @override
  double get fontSize;

  /// Text color
  @override
  String get textColor;

  /// Background color
  @override
  String get backgroundColor;

  /// Font weight
  @override
  String get fontWeight;

  /// Text alignment
  @override
  String get alignment;

  /// Display duration in seconds
  @override
  int get displayDuration;

  /// Animation type
  @override
  String get animation;

  /// Create a copy of HUDStyleSettings
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$HUDStyleSettingsImplCopyWith<_$HUDStyleSettingsImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

HUDQueueItem _$HUDQueueItemFromJson(Map<String, dynamic> json) {
  return _HUDQueueItem.fromJson(json);
}

/// @nodoc
mixin _$HUDQueueItem {
  /// Content to display
  String get content => throw _privateConstructorUsedError;

  /// Content type
  HUDContentType get type => throw _privateConstructorUsedError;

  /// Display position
  HUDPosition get position => throw _privateConstructorUsedError;

  /// Priority (higher numbers = higher priority)
  int get priority => throw _privateConstructorUsedError;

  /// When this item was queued
  DateTime get queuedAt => throw _privateConstructorUsedError;

  /// Display duration
  Duration get duration => throw _privateConstructorUsedError;

  /// Style overrides
  HUDStyleSettings? get styleOverrides => throw _privateConstructorUsedError;

  /// Serializes this HUDQueueItem to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of HUDQueueItem
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $HUDQueueItemCopyWith<HUDQueueItem> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $HUDQueueItemCopyWith<$Res> {
  factory $HUDQueueItemCopyWith(
    HUDQueueItem value,
    $Res Function(HUDQueueItem) then,
  ) = _$HUDQueueItemCopyWithImpl<$Res, HUDQueueItem>;
  @useResult
  $Res call({
    String content,
    HUDContentType type,
    HUDPosition position,
    int priority,
    DateTime queuedAt,
    Duration duration,
    HUDStyleSettings? styleOverrides,
  });

  $HUDStyleSettingsCopyWith<$Res>? get styleOverrides;
}

/// @nodoc
class _$HUDQueueItemCopyWithImpl<$Res, $Val extends HUDQueueItem>
    implements $HUDQueueItemCopyWith<$Res> {
  _$HUDQueueItemCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of HUDQueueItem
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? content = null,
    Object? type = null,
    Object? position = null,
    Object? priority = null,
    Object? queuedAt = null,
    Object? duration = null,
    Object? styleOverrides = freezed,
  }) {
    return _then(
      _value.copyWith(
            content:
                null == content
                    ? _value.content
                    : content // ignore: cast_nullable_to_non_nullable
                        as String,
            type:
                null == type
                    ? _value.type
                    : type // ignore: cast_nullable_to_non_nullable
                        as HUDContentType,
            position:
                null == position
                    ? _value.position
                    : position // ignore: cast_nullable_to_non_nullable
                        as HUDPosition,
            priority:
                null == priority
                    ? _value.priority
                    : priority // ignore: cast_nullable_to_non_nullable
                        as int,
            queuedAt:
                null == queuedAt
                    ? _value.queuedAt
                    : queuedAt // ignore: cast_nullable_to_non_nullable
                        as DateTime,
            duration:
                null == duration
                    ? _value.duration
                    : duration // ignore: cast_nullable_to_non_nullable
                        as Duration,
            styleOverrides:
                freezed == styleOverrides
                    ? _value.styleOverrides
                    : styleOverrides // ignore: cast_nullable_to_non_nullable
                        as HUDStyleSettings?,
          )
          as $Val,
    );
  }

  /// Create a copy of HUDQueueItem
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $HUDStyleSettingsCopyWith<$Res>? get styleOverrides {
    if (_value.styleOverrides == null) {
      return null;
    }

    return $HUDStyleSettingsCopyWith<$Res>(_value.styleOverrides!, (value) {
      return _then(_value.copyWith(styleOverrides: value) as $Val);
    });
  }
}

/// @nodoc
abstract class _$$HUDQueueItemImplCopyWith<$Res>
    implements $HUDQueueItemCopyWith<$Res> {
  factory _$$HUDQueueItemImplCopyWith(
    _$HUDQueueItemImpl value,
    $Res Function(_$HUDQueueItemImpl) then,
  ) = __$$HUDQueueItemImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String content,
    HUDContentType type,
    HUDPosition position,
    int priority,
    DateTime queuedAt,
    Duration duration,
    HUDStyleSettings? styleOverrides,
  });

  @override
  $HUDStyleSettingsCopyWith<$Res>? get styleOverrides;
}

/// @nodoc
class __$$HUDQueueItemImplCopyWithImpl<$Res>
    extends _$HUDQueueItemCopyWithImpl<$Res, _$HUDQueueItemImpl>
    implements _$$HUDQueueItemImplCopyWith<$Res> {
  __$$HUDQueueItemImplCopyWithImpl(
    _$HUDQueueItemImpl _value,
    $Res Function(_$HUDQueueItemImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of HUDQueueItem
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? content = null,
    Object? type = null,
    Object? position = null,
    Object? priority = null,
    Object? queuedAt = null,
    Object? duration = null,
    Object? styleOverrides = freezed,
  }) {
    return _then(
      _$HUDQueueItemImpl(
        content:
            null == content
                ? _value.content
                : content // ignore: cast_nullable_to_non_nullable
                    as String,
        type:
            null == type
                ? _value.type
                : type // ignore: cast_nullable_to_non_nullable
                    as HUDContentType,
        position:
            null == position
                ? _value.position
                : position // ignore: cast_nullable_to_non_nullable
                    as HUDPosition,
        priority:
            null == priority
                ? _value.priority
                : priority // ignore: cast_nullable_to_non_nullable
                    as int,
        queuedAt:
            null == queuedAt
                ? _value.queuedAt
                : queuedAt // ignore: cast_nullable_to_non_nullable
                    as DateTime,
        duration:
            null == duration
                ? _value.duration
                : duration // ignore: cast_nullable_to_non_nullable
                    as Duration,
        styleOverrides:
            freezed == styleOverrides
                ? _value.styleOverrides
                : styleOverrides // ignore: cast_nullable_to_non_nullable
                    as HUDStyleSettings?,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$HUDQueueItemImpl implements _HUDQueueItem {
  const _$HUDQueueItemImpl({
    required this.content,
    required this.type,
    this.position = HUDPosition.center,
    this.priority = 1,
    required this.queuedAt,
    this.duration = const Duration(seconds: 5),
    this.styleOverrides,
  });

  factory _$HUDQueueItemImpl.fromJson(Map<String, dynamic> json) =>
      _$$HUDQueueItemImplFromJson(json);

  /// Content to display
  @override
  final String content;

  /// Content type
  @override
  final HUDContentType type;

  /// Display position
  @override
  @JsonKey()
  final HUDPosition position;

  /// Priority (higher numbers = higher priority)
  @override
  @JsonKey()
  final int priority;

  /// When this item was queued
  @override
  final DateTime queuedAt;

  /// Display duration
  @override
  @JsonKey()
  final Duration duration;

  /// Style overrides
  @override
  final HUDStyleSettings? styleOverrides;

  @override
  String toString() {
    return 'HUDQueueItem(content: $content, type: $type, position: $position, priority: $priority, queuedAt: $queuedAt, duration: $duration, styleOverrides: $styleOverrides)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$HUDQueueItemImpl &&
            (identical(other.content, content) || other.content == content) &&
            (identical(other.type, type) || other.type == type) &&
            (identical(other.position, position) ||
                other.position == position) &&
            (identical(other.priority, priority) ||
                other.priority == priority) &&
            (identical(other.queuedAt, queuedAt) ||
                other.queuedAt == queuedAt) &&
            (identical(other.duration, duration) ||
                other.duration == duration) &&
            (identical(other.styleOverrides, styleOverrides) ||
                other.styleOverrides == styleOverrides));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    content,
    type,
    position,
    priority,
    queuedAt,
    duration,
    styleOverrides,
  );

  /// Create a copy of HUDQueueItem
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$HUDQueueItemImplCopyWith<_$HUDQueueItemImpl> get copyWith =>
      __$$HUDQueueItemImplCopyWithImpl<_$HUDQueueItemImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$HUDQueueItemImplToJson(this);
  }
}

abstract class _HUDQueueItem implements HUDQueueItem {
  const factory _HUDQueueItem({
    required final String content,
    required final HUDContentType type,
    final HUDPosition position,
    final int priority,
    required final DateTime queuedAt,
    final Duration duration,
    final HUDStyleSettings? styleOverrides,
  }) = _$HUDQueueItemImpl;

  factory _HUDQueueItem.fromJson(Map<String, dynamic> json) =
      _$HUDQueueItemImpl.fromJson;

  /// Content to display
  @override
  String get content;

  /// Content type
  @override
  HUDContentType get type;

  /// Display position
  @override
  HUDPosition get position;

  /// Priority (higher numbers = higher priority)
  @override
  int get priority;

  /// When this item was queued
  @override
  DateTime get queuedAt;

  /// Display duration
  @override
  Duration get duration;

  /// Style overrides
  @override
  HUDStyleSettings? get styleOverrides;

  /// Create a copy of HUDQueueItem
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$HUDQueueItemImplCopyWith<_$HUDQueueItemImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

GlassesCapabilities _$GlassesCapabilitiesFromJson(Map<String, dynamic> json) {
  return _GlassesCapabilities.fromJson(json);
}

/// @nodoc
mixin _$GlassesCapabilities {
  /// Supports text display
  bool get supportsText => throw _privateConstructorUsedError;

  /// Supports images
  bool get supportsImages => throw _privateConstructorUsedError;

  /// Supports animations
  bool get supportsAnimations => throw _privateConstructorUsedError;

  /// Supports touch gestures
  bool get supportsTouchGestures => throw _privateConstructorUsedError;

  /// Supports voice commands
  bool get supportsVoiceCommands => throw _privateConstructorUsedError;

  /// Maximum text length
  int get maxTextLength => throw _privateConstructorUsedError;

  /// Supported display positions
  List<HUDPosition> get supportedPositions =>
      throw _privateConstructorUsedError;

  /// Battery monitoring capability
  bool get supportsBatteryMonitoring => throw _privateConstructorUsedError;

  /// Firmware update capability
  bool get supportsFirmwareUpdate => throw _privateConstructorUsedError;

  /// Serializes this GlassesCapabilities to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of GlassesCapabilities
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $GlassesCapabilitiesCopyWith<GlassesCapabilities> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $GlassesCapabilitiesCopyWith<$Res> {
  factory $GlassesCapabilitiesCopyWith(
    GlassesCapabilities value,
    $Res Function(GlassesCapabilities) then,
  ) = _$GlassesCapabilitiesCopyWithImpl<$Res, GlassesCapabilities>;
  @useResult
  $Res call({
    bool supportsText,
    bool supportsImages,
    bool supportsAnimations,
    bool supportsTouchGestures,
    bool supportsVoiceCommands,
    int maxTextLength,
    List<HUDPosition> supportedPositions,
    bool supportsBatteryMonitoring,
    bool supportsFirmwareUpdate,
  });
}

/// @nodoc
class _$GlassesCapabilitiesCopyWithImpl<$Res, $Val extends GlassesCapabilities>
    implements $GlassesCapabilitiesCopyWith<$Res> {
  _$GlassesCapabilitiesCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of GlassesCapabilities
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? supportsText = null,
    Object? supportsImages = null,
    Object? supportsAnimations = null,
    Object? supportsTouchGestures = null,
    Object? supportsVoiceCommands = null,
    Object? maxTextLength = null,
    Object? supportedPositions = null,
    Object? supportsBatteryMonitoring = null,
    Object? supportsFirmwareUpdate = null,
  }) {
    return _then(
      _value.copyWith(
            supportsText:
                null == supportsText
                    ? _value.supportsText
                    : supportsText // ignore: cast_nullable_to_non_nullable
                        as bool,
            supportsImages:
                null == supportsImages
                    ? _value.supportsImages
                    : supportsImages // ignore: cast_nullable_to_non_nullable
                        as bool,
            supportsAnimations:
                null == supportsAnimations
                    ? _value.supportsAnimations
                    : supportsAnimations // ignore: cast_nullable_to_non_nullable
                        as bool,
            supportsTouchGestures:
                null == supportsTouchGestures
                    ? _value.supportsTouchGestures
                    : supportsTouchGestures // ignore: cast_nullable_to_non_nullable
                        as bool,
            supportsVoiceCommands:
                null == supportsVoiceCommands
                    ? _value.supportsVoiceCommands
                    : supportsVoiceCommands // ignore: cast_nullable_to_non_nullable
                        as bool,
            maxTextLength:
                null == maxTextLength
                    ? _value.maxTextLength
                    : maxTextLength // ignore: cast_nullable_to_non_nullable
                        as int,
            supportedPositions:
                null == supportedPositions
                    ? _value.supportedPositions
                    : supportedPositions // ignore: cast_nullable_to_non_nullable
                        as List<HUDPosition>,
            supportsBatteryMonitoring:
                null == supportsBatteryMonitoring
                    ? _value.supportsBatteryMonitoring
                    : supportsBatteryMonitoring // ignore: cast_nullable_to_non_nullable
                        as bool,
            supportsFirmwareUpdate:
                null == supportsFirmwareUpdate
                    ? _value.supportsFirmwareUpdate
                    : supportsFirmwareUpdate // ignore: cast_nullable_to_non_nullable
                        as bool,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$GlassesCapabilitiesImplCopyWith<$Res>
    implements $GlassesCapabilitiesCopyWith<$Res> {
  factory _$$GlassesCapabilitiesImplCopyWith(
    _$GlassesCapabilitiesImpl value,
    $Res Function(_$GlassesCapabilitiesImpl) then,
  ) = __$$GlassesCapabilitiesImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    bool supportsText,
    bool supportsImages,
    bool supportsAnimations,
    bool supportsTouchGestures,
    bool supportsVoiceCommands,
    int maxTextLength,
    List<HUDPosition> supportedPositions,
    bool supportsBatteryMonitoring,
    bool supportsFirmwareUpdate,
  });
}

/// @nodoc
class __$$GlassesCapabilitiesImplCopyWithImpl<$Res>
    extends _$GlassesCapabilitiesCopyWithImpl<$Res, _$GlassesCapabilitiesImpl>
    implements _$$GlassesCapabilitiesImplCopyWith<$Res> {
  __$$GlassesCapabilitiesImplCopyWithImpl(
    _$GlassesCapabilitiesImpl _value,
    $Res Function(_$GlassesCapabilitiesImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of GlassesCapabilities
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? supportsText = null,
    Object? supportsImages = null,
    Object? supportsAnimations = null,
    Object? supportsTouchGestures = null,
    Object? supportsVoiceCommands = null,
    Object? maxTextLength = null,
    Object? supportedPositions = null,
    Object? supportsBatteryMonitoring = null,
    Object? supportsFirmwareUpdate = null,
  }) {
    return _then(
      _$GlassesCapabilitiesImpl(
        supportsText:
            null == supportsText
                ? _value.supportsText
                : supportsText // ignore: cast_nullable_to_non_nullable
                    as bool,
        supportsImages:
            null == supportsImages
                ? _value.supportsImages
                : supportsImages // ignore: cast_nullable_to_non_nullable
                    as bool,
        supportsAnimations:
            null == supportsAnimations
                ? _value.supportsAnimations
                : supportsAnimations // ignore: cast_nullable_to_non_nullable
                    as bool,
        supportsTouchGestures:
            null == supportsTouchGestures
                ? _value.supportsTouchGestures
                : supportsTouchGestures // ignore: cast_nullable_to_non_nullable
                    as bool,
        supportsVoiceCommands:
            null == supportsVoiceCommands
                ? _value.supportsVoiceCommands
                : supportsVoiceCommands // ignore: cast_nullable_to_non_nullable
                    as bool,
        maxTextLength:
            null == maxTextLength
                ? _value.maxTextLength
                : maxTextLength // ignore: cast_nullable_to_non_nullable
                    as int,
        supportedPositions:
            null == supportedPositions
                ? _value._supportedPositions
                : supportedPositions // ignore: cast_nullable_to_non_nullable
                    as List<HUDPosition>,
        supportsBatteryMonitoring:
            null == supportsBatteryMonitoring
                ? _value.supportsBatteryMonitoring
                : supportsBatteryMonitoring // ignore: cast_nullable_to_non_nullable
                    as bool,
        supportsFirmwareUpdate:
            null == supportsFirmwareUpdate
                ? _value.supportsFirmwareUpdate
                : supportsFirmwareUpdate // ignore: cast_nullable_to_non_nullable
                    as bool,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$GlassesCapabilitiesImpl implements _GlassesCapabilities {
  const _$GlassesCapabilitiesImpl({
    this.supportsText = true,
    this.supportsImages = false,
    this.supportsAnimations = false,
    this.supportsTouchGestures = true,
    this.supportsVoiceCommands = false,
    this.maxTextLength = 256,
    final List<HUDPosition> supportedPositions = const [HUDPosition.center],
    this.supportsBatteryMonitoring = true,
    this.supportsFirmwareUpdate = true,
  }) : _supportedPositions = supportedPositions;

  factory _$GlassesCapabilitiesImpl.fromJson(Map<String, dynamic> json) =>
      _$$GlassesCapabilitiesImplFromJson(json);

  /// Supports text display
  @override
  @JsonKey()
  final bool supportsText;

  /// Supports images
  @override
  @JsonKey()
  final bool supportsImages;

  /// Supports animations
  @override
  @JsonKey()
  final bool supportsAnimations;

  /// Supports touch gestures
  @override
  @JsonKey()
  final bool supportsTouchGestures;

  /// Supports voice commands
  @override
  @JsonKey()
  final bool supportsVoiceCommands;

  /// Maximum text length
  @override
  @JsonKey()
  final int maxTextLength;

  /// Supported display positions
  final List<HUDPosition> _supportedPositions;

  /// Supported display positions
  @override
  @JsonKey()
  List<HUDPosition> get supportedPositions {
    if (_supportedPositions is EqualUnmodifiableListView)
      return _supportedPositions;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_supportedPositions);
  }

  /// Battery monitoring capability
  @override
  @JsonKey()
  final bool supportsBatteryMonitoring;

  /// Firmware update capability
  @override
  @JsonKey()
  final bool supportsFirmwareUpdate;

  @override
  String toString() {
    return 'GlassesCapabilities(supportsText: $supportsText, supportsImages: $supportsImages, supportsAnimations: $supportsAnimations, supportsTouchGestures: $supportsTouchGestures, supportsVoiceCommands: $supportsVoiceCommands, maxTextLength: $maxTextLength, supportedPositions: $supportedPositions, supportsBatteryMonitoring: $supportsBatteryMonitoring, supportsFirmwareUpdate: $supportsFirmwareUpdate)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$GlassesCapabilitiesImpl &&
            (identical(other.supportsText, supportsText) ||
                other.supportsText == supportsText) &&
            (identical(other.supportsImages, supportsImages) ||
                other.supportsImages == supportsImages) &&
            (identical(other.supportsAnimations, supportsAnimations) ||
                other.supportsAnimations == supportsAnimations) &&
            (identical(other.supportsTouchGestures, supportsTouchGestures) ||
                other.supportsTouchGestures == supportsTouchGestures) &&
            (identical(other.supportsVoiceCommands, supportsVoiceCommands) ||
                other.supportsVoiceCommands == supportsVoiceCommands) &&
            (identical(other.maxTextLength, maxTextLength) ||
                other.maxTextLength == maxTextLength) &&
            const DeepCollectionEquality().equals(
              other._supportedPositions,
              _supportedPositions,
            ) &&
            (identical(
                  other.supportsBatteryMonitoring,
                  supportsBatteryMonitoring,
                ) ||
                other.supportsBatteryMonitoring == supportsBatteryMonitoring) &&
            (identical(other.supportsFirmwareUpdate, supportsFirmwareUpdate) ||
                other.supportsFirmwareUpdate == supportsFirmwareUpdate));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    supportsText,
    supportsImages,
    supportsAnimations,
    supportsTouchGestures,
    supportsVoiceCommands,
    maxTextLength,
    const DeepCollectionEquality().hash(_supportedPositions),
    supportsBatteryMonitoring,
    supportsFirmwareUpdate,
  );

  /// Create a copy of GlassesCapabilities
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$GlassesCapabilitiesImplCopyWith<_$GlassesCapabilitiesImpl> get copyWith =>
      __$$GlassesCapabilitiesImplCopyWithImpl<_$GlassesCapabilitiesImpl>(
        this,
        _$identity,
      );

  @override
  Map<String, dynamic> toJson() {
    return _$$GlassesCapabilitiesImplToJson(this);
  }
}

abstract class _GlassesCapabilities implements GlassesCapabilities {
  const factory _GlassesCapabilities({
    final bool supportsText,
    final bool supportsImages,
    final bool supportsAnimations,
    final bool supportsTouchGestures,
    final bool supportsVoiceCommands,
    final int maxTextLength,
    final List<HUDPosition> supportedPositions,
    final bool supportsBatteryMonitoring,
    final bool supportsFirmwareUpdate,
  }) = _$GlassesCapabilitiesImpl;

  factory _GlassesCapabilities.fromJson(Map<String, dynamic> json) =
      _$GlassesCapabilitiesImpl.fromJson;

  /// Supports text display
  @override
  bool get supportsText;

  /// Supports images
  @override
  bool get supportsImages;

  /// Supports animations
  @override
  bool get supportsAnimations;

  /// Supports touch gestures
  @override
  bool get supportsTouchGestures;

  /// Supports voice commands
  @override
  bool get supportsVoiceCommands;

  /// Maximum text length
  @override
  int get maxTextLength;

  /// Supported display positions
  @override
  List<HUDPosition> get supportedPositions;

  /// Battery monitoring capability
  @override
  bool get supportsBatteryMonitoring;

  /// Firmware update capability
  @override
  bool get supportsFirmwareUpdate;

  /// Create a copy of GlassesCapabilities
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$GlassesCapabilitiesImplCopyWith<_$GlassesCapabilitiesImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

GlassesConfiguration _$GlassesConfigurationFromJson(Map<String, dynamic> json) {
  return _GlassesConfiguration.fromJson(json);
}

/// @nodoc
mixin _$GlassesConfiguration {
  /// Auto-reconnect setting
  bool get autoReconnect => throw _privateConstructorUsedError;

  /// Default brightness
  double get defaultBrightness => throw _privateConstructorUsedError;

  /// Gesture sensitivity
  double get gestureSensitivity => throw _privateConstructorUsedError;

  /// Display timeout in seconds
  int get displayTimeout => throw _privateConstructorUsedError;

  /// Power save mode enabled
  bool get powerSaveMode => throw _privateConstructorUsedError;

  /// Notification settings
  NotificationSettings get notifications => throw _privateConstructorUsedError;

  /// Serializes this GlassesConfiguration to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of GlassesConfiguration
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $GlassesConfigurationCopyWith<GlassesConfiguration> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $GlassesConfigurationCopyWith<$Res> {
  factory $GlassesConfigurationCopyWith(
    GlassesConfiguration value,
    $Res Function(GlassesConfiguration) then,
  ) = _$GlassesConfigurationCopyWithImpl<$Res, GlassesConfiguration>;
  @useResult
  $Res call({
    bool autoReconnect,
    double defaultBrightness,
    double gestureSensitivity,
    int displayTimeout,
    bool powerSaveMode,
    NotificationSettings notifications,
  });

  $NotificationSettingsCopyWith<$Res> get notifications;
}

/// @nodoc
class _$GlassesConfigurationCopyWithImpl<
  $Res,
  $Val extends GlassesConfiguration
>
    implements $GlassesConfigurationCopyWith<$Res> {
  _$GlassesConfigurationCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of GlassesConfiguration
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? autoReconnect = null,
    Object? defaultBrightness = null,
    Object? gestureSensitivity = null,
    Object? displayTimeout = null,
    Object? powerSaveMode = null,
    Object? notifications = null,
  }) {
    return _then(
      _value.copyWith(
            autoReconnect:
                null == autoReconnect
                    ? _value.autoReconnect
                    : autoReconnect // ignore: cast_nullable_to_non_nullable
                        as bool,
            defaultBrightness:
                null == defaultBrightness
                    ? _value.defaultBrightness
                    : defaultBrightness // ignore: cast_nullable_to_non_nullable
                        as double,
            gestureSensitivity:
                null == gestureSensitivity
                    ? _value.gestureSensitivity
                    : gestureSensitivity // ignore: cast_nullable_to_non_nullable
                        as double,
            displayTimeout:
                null == displayTimeout
                    ? _value.displayTimeout
                    : displayTimeout // ignore: cast_nullable_to_non_nullable
                        as int,
            powerSaveMode:
                null == powerSaveMode
                    ? _value.powerSaveMode
                    : powerSaveMode // ignore: cast_nullable_to_non_nullable
                        as bool,
            notifications:
                null == notifications
                    ? _value.notifications
                    : notifications // ignore: cast_nullable_to_non_nullable
                        as NotificationSettings,
          )
          as $Val,
    );
  }

  /// Create a copy of GlassesConfiguration
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $NotificationSettingsCopyWith<$Res> get notifications {
    return $NotificationSettingsCopyWith<$Res>(_value.notifications, (value) {
      return _then(_value.copyWith(notifications: value) as $Val);
    });
  }
}

/// @nodoc
abstract class _$$GlassesConfigurationImplCopyWith<$Res>
    implements $GlassesConfigurationCopyWith<$Res> {
  factory _$$GlassesConfigurationImplCopyWith(
    _$GlassesConfigurationImpl value,
    $Res Function(_$GlassesConfigurationImpl) then,
  ) = __$$GlassesConfigurationImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    bool autoReconnect,
    double defaultBrightness,
    double gestureSensitivity,
    int displayTimeout,
    bool powerSaveMode,
    NotificationSettings notifications,
  });

  @override
  $NotificationSettingsCopyWith<$Res> get notifications;
}

/// @nodoc
class __$$GlassesConfigurationImplCopyWithImpl<$Res>
    extends _$GlassesConfigurationCopyWithImpl<$Res, _$GlassesConfigurationImpl>
    implements _$$GlassesConfigurationImplCopyWith<$Res> {
  __$$GlassesConfigurationImplCopyWithImpl(
    _$GlassesConfigurationImpl _value,
    $Res Function(_$GlassesConfigurationImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of GlassesConfiguration
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? autoReconnect = null,
    Object? defaultBrightness = null,
    Object? gestureSensitivity = null,
    Object? displayTimeout = null,
    Object? powerSaveMode = null,
    Object? notifications = null,
  }) {
    return _then(
      _$GlassesConfigurationImpl(
        autoReconnect:
            null == autoReconnect
                ? _value.autoReconnect
                : autoReconnect // ignore: cast_nullable_to_non_nullable
                    as bool,
        defaultBrightness:
            null == defaultBrightness
                ? _value.defaultBrightness
                : defaultBrightness // ignore: cast_nullable_to_non_nullable
                    as double,
        gestureSensitivity:
            null == gestureSensitivity
                ? _value.gestureSensitivity
                : gestureSensitivity // ignore: cast_nullable_to_non_nullable
                    as double,
        displayTimeout:
            null == displayTimeout
                ? _value.displayTimeout
                : displayTimeout // ignore: cast_nullable_to_non_nullable
                    as int,
        powerSaveMode:
            null == powerSaveMode
                ? _value.powerSaveMode
                : powerSaveMode // ignore: cast_nullable_to_non_nullable
                    as bool,
        notifications:
            null == notifications
                ? _value.notifications
                : notifications // ignore: cast_nullable_to_non_nullable
                    as NotificationSettings,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$GlassesConfigurationImpl implements _GlassesConfiguration {
  const _$GlassesConfigurationImpl({
    this.autoReconnect = true,
    this.defaultBrightness = 0.8,
    this.gestureSensitivity = 0.5,
    this.displayTimeout = 10,
    this.powerSaveMode = false,
    this.notifications = const NotificationSettings(),
  });

  factory _$GlassesConfigurationImpl.fromJson(Map<String, dynamic> json) =>
      _$$GlassesConfigurationImplFromJson(json);

  /// Auto-reconnect setting
  @override
  @JsonKey()
  final bool autoReconnect;

  /// Default brightness
  @override
  @JsonKey()
  final double defaultBrightness;

  /// Gesture sensitivity
  @override
  @JsonKey()
  final double gestureSensitivity;

  /// Display timeout in seconds
  @override
  @JsonKey()
  final int displayTimeout;

  /// Power save mode enabled
  @override
  @JsonKey()
  final bool powerSaveMode;

  /// Notification settings
  @override
  @JsonKey()
  final NotificationSettings notifications;

  @override
  String toString() {
    return 'GlassesConfiguration(autoReconnect: $autoReconnect, defaultBrightness: $defaultBrightness, gestureSensitivity: $gestureSensitivity, displayTimeout: $displayTimeout, powerSaveMode: $powerSaveMode, notifications: $notifications)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$GlassesConfigurationImpl &&
            (identical(other.autoReconnect, autoReconnect) ||
                other.autoReconnect == autoReconnect) &&
            (identical(other.defaultBrightness, defaultBrightness) ||
                other.defaultBrightness == defaultBrightness) &&
            (identical(other.gestureSensitivity, gestureSensitivity) ||
                other.gestureSensitivity == gestureSensitivity) &&
            (identical(other.displayTimeout, displayTimeout) ||
                other.displayTimeout == displayTimeout) &&
            (identical(other.powerSaveMode, powerSaveMode) ||
                other.powerSaveMode == powerSaveMode) &&
            (identical(other.notifications, notifications) ||
                other.notifications == notifications));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    autoReconnect,
    defaultBrightness,
    gestureSensitivity,
    displayTimeout,
    powerSaveMode,
    notifications,
  );

  /// Create a copy of GlassesConfiguration
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$GlassesConfigurationImplCopyWith<_$GlassesConfigurationImpl>
  get copyWith =>
      __$$GlassesConfigurationImplCopyWithImpl<_$GlassesConfigurationImpl>(
        this,
        _$identity,
      );

  @override
  Map<String, dynamic> toJson() {
    return _$$GlassesConfigurationImplToJson(this);
  }
}

abstract class _GlassesConfiguration implements GlassesConfiguration {
  const factory _GlassesConfiguration({
    final bool autoReconnect,
    final double defaultBrightness,
    final double gestureSensitivity,
    final int displayTimeout,
    final bool powerSaveMode,
    final NotificationSettings notifications,
  }) = _$GlassesConfigurationImpl;

  factory _GlassesConfiguration.fromJson(Map<String, dynamic> json) =
      _$GlassesConfigurationImpl.fromJson;

  /// Auto-reconnect setting
  @override
  bool get autoReconnect;

  /// Default brightness
  @override
  double get defaultBrightness;

  /// Gesture sensitivity
  @override
  double get gestureSensitivity;

  /// Display timeout in seconds
  @override
  int get displayTimeout;

  /// Power save mode enabled
  @override
  bool get powerSaveMode;

  /// Notification settings
  @override
  NotificationSettings get notifications;

  /// Create a copy of GlassesConfiguration
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$GlassesConfigurationImplCopyWith<_$GlassesConfigurationImpl>
  get copyWith => throw _privateConstructorUsedError;
}

NotificationSettings _$NotificationSettingsFromJson(Map<String, dynamic> json) {
  return _NotificationSettings.fromJson(json);
}

/// @nodoc
mixin _$NotificationSettings {
  /// Enable notifications
  bool get enabled => throw _privateConstructorUsedError;

  /// Priority threshold
  int get priorityThreshold => throw _privateConstructorUsedError;

  /// Vibration enabled
  bool get vibrationEnabled => throw _privateConstructorUsedError;

  /// Sound enabled
  bool get soundEnabled => throw _privateConstructorUsedError;

  /// Serializes this NotificationSettings to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of NotificationSettings
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $NotificationSettingsCopyWith<NotificationSettings> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $NotificationSettingsCopyWith<$Res> {
  factory $NotificationSettingsCopyWith(
    NotificationSettings value,
    $Res Function(NotificationSettings) then,
  ) = _$NotificationSettingsCopyWithImpl<$Res, NotificationSettings>;
  @useResult
  $Res call({
    bool enabled,
    int priorityThreshold,
    bool vibrationEnabled,
    bool soundEnabled,
  });
}

/// @nodoc
class _$NotificationSettingsCopyWithImpl<
  $Res,
  $Val extends NotificationSettings
>
    implements $NotificationSettingsCopyWith<$Res> {
  _$NotificationSettingsCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of NotificationSettings
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? enabled = null,
    Object? priorityThreshold = null,
    Object? vibrationEnabled = null,
    Object? soundEnabled = null,
  }) {
    return _then(
      _value.copyWith(
            enabled:
                null == enabled
                    ? _value.enabled
                    : enabled // ignore: cast_nullable_to_non_nullable
                        as bool,
            priorityThreshold:
                null == priorityThreshold
                    ? _value.priorityThreshold
                    : priorityThreshold // ignore: cast_nullable_to_non_nullable
                        as int,
            vibrationEnabled:
                null == vibrationEnabled
                    ? _value.vibrationEnabled
                    : vibrationEnabled // ignore: cast_nullable_to_non_nullable
                        as bool,
            soundEnabled:
                null == soundEnabled
                    ? _value.soundEnabled
                    : soundEnabled // ignore: cast_nullable_to_non_nullable
                        as bool,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$NotificationSettingsImplCopyWith<$Res>
    implements $NotificationSettingsCopyWith<$Res> {
  factory _$$NotificationSettingsImplCopyWith(
    _$NotificationSettingsImpl value,
    $Res Function(_$NotificationSettingsImpl) then,
  ) = __$$NotificationSettingsImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    bool enabled,
    int priorityThreshold,
    bool vibrationEnabled,
    bool soundEnabled,
  });
}

/// @nodoc
class __$$NotificationSettingsImplCopyWithImpl<$Res>
    extends _$NotificationSettingsCopyWithImpl<$Res, _$NotificationSettingsImpl>
    implements _$$NotificationSettingsImplCopyWith<$Res> {
  __$$NotificationSettingsImplCopyWithImpl(
    _$NotificationSettingsImpl _value,
    $Res Function(_$NotificationSettingsImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of NotificationSettings
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? enabled = null,
    Object? priorityThreshold = null,
    Object? vibrationEnabled = null,
    Object? soundEnabled = null,
  }) {
    return _then(
      _$NotificationSettingsImpl(
        enabled:
            null == enabled
                ? _value.enabled
                : enabled // ignore: cast_nullable_to_non_nullable
                    as bool,
        priorityThreshold:
            null == priorityThreshold
                ? _value.priorityThreshold
                : priorityThreshold // ignore: cast_nullable_to_non_nullable
                    as int,
        vibrationEnabled:
            null == vibrationEnabled
                ? _value.vibrationEnabled
                : vibrationEnabled // ignore: cast_nullable_to_non_nullable
                    as bool,
        soundEnabled:
            null == soundEnabled
                ? _value.soundEnabled
                : soundEnabled // ignore: cast_nullable_to_non_nullable
                    as bool,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$NotificationSettingsImpl implements _NotificationSettings {
  const _$NotificationSettingsImpl({
    this.enabled = true,
    this.priorityThreshold = 1,
    this.vibrationEnabled = false,
    this.soundEnabled = false,
  });

  factory _$NotificationSettingsImpl.fromJson(Map<String, dynamic> json) =>
      _$$NotificationSettingsImplFromJson(json);

  /// Enable notifications
  @override
  @JsonKey()
  final bool enabled;

  /// Priority threshold
  @override
  @JsonKey()
  final int priorityThreshold;

  /// Vibration enabled
  @override
  @JsonKey()
  final bool vibrationEnabled;

  /// Sound enabled
  @override
  @JsonKey()
  final bool soundEnabled;

  @override
  String toString() {
    return 'NotificationSettings(enabled: $enabled, priorityThreshold: $priorityThreshold, vibrationEnabled: $vibrationEnabled, soundEnabled: $soundEnabled)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$NotificationSettingsImpl &&
            (identical(other.enabled, enabled) || other.enabled == enabled) &&
            (identical(other.priorityThreshold, priorityThreshold) ||
                other.priorityThreshold == priorityThreshold) &&
            (identical(other.vibrationEnabled, vibrationEnabled) ||
                other.vibrationEnabled == vibrationEnabled) &&
            (identical(other.soundEnabled, soundEnabled) ||
                other.soundEnabled == soundEnabled));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    enabled,
    priorityThreshold,
    vibrationEnabled,
    soundEnabled,
  );

  /// Create a copy of NotificationSettings
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$NotificationSettingsImplCopyWith<_$NotificationSettingsImpl>
  get copyWith =>
      __$$NotificationSettingsImplCopyWithImpl<_$NotificationSettingsImpl>(
        this,
        _$identity,
      );

  @override
  Map<String, dynamic> toJson() {
    return _$$NotificationSettingsImplToJson(this);
  }
}

abstract class _NotificationSettings implements NotificationSettings {
  const factory _NotificationSettings({
    final bool enabled,
    final int priorityThreshold,
    final bool vibrationEnabled,
    final bool soundEnabled,
  }) = _$NotificationSettingsImpl;

  factory _NotificationSettings.fromJson(Map<String, dynamic> json) =
      _$NotificationSettingsImpl.fromJson;

  /// Enable notifications
  @override
  bool get enabled;

  /// Priority threshold
  @override
  int get priorityThreshold;

  /// Vibration enabled
  @override
  bool get vibrationEnabled;

  /// Sound enabled
  @override
  bool get soundEnabled;

  /// Create a copy of NotificationSettings
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$NotificationSettingsImplCopyWith<_$NotificationSettingsImpl>
  get copyWith => throw _privateConstructorUsedError;
}
