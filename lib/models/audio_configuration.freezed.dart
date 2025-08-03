// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'audio_configuration.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

AudioConfiguration _$AudioConfigurationFromJson(Map<String, dynamic> json) {
  return _AudioConfiguration.fromJson(json);
}

/// @nodoc
mixin _$AudioConfiguration {
  /// Sample rate in Hz (e.g., 16000 for 16kHz)
  int get sampleRate => throw _privateConstructorUsedError;

  /// Number of audio channels (1 for mono, 2 for stereo)
  int get channels => throw _privateConstructorUsedError;

  /// Bit rate for encoding (in bits per second)
  int get bitRate => throw _privateConstructorUsedError;

  /// Audio quality level
  AudioQuality get quality => throw _privateConstructorUsedError;

  /// Audio format for recording
  AudioFormat get format => throw _privateConstructorUsedError;

  /// Enable noise reduction
  bool get enableNoiseReduction => throw _privateConstructorUsedError;

  /// Enable echo cancellation
  bool get enableEchoCancellation => throw _privateConstructorUsedError;

  /// Enable automatic gain control
  bool get enableAutomaticGainControl => throw _privateConstructorUsedError;

  /// Audio gain level (0.0 to 2.0, 1.0 is normal)
  double get gainLevel => throw _privateConstructorUsedError;

  /// Enable voice activity detection
  bool get enableVoiceActivityDetection => throw _privateConstructorUsedError;

  /// Voice activity detection threshold (0.0 to 1.0)
  double get vadThreshold => throw _privateConstructorUsedError;

  /// Buffer size in frames for audio processing
  int get bufferSize => throw _privateConstructorUsedError;

  /// Selected audio input device ID
  String? get selectedDeviceId => throw _privateConstructorUsedError;

  /// Enable real-time audio streaming
  bool get enableRealTimeStreaming => throw _privateConstructorUsedError;

  /// Audio chunk duration for processing (in milliseconds)
  int get chunkDurationMs => throw _privateConstructorUsedError;

  /// Serializes this AudioConfiguration to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of AudioConfiguration
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $AudioConfigurationCopyWith<AudioConfiguration> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $AudioConfigurationCopyWith<$Res> {
  factory $AudioConfigurationCopyWith(
    AudioConfiguration value,
    $Res Function(AudioConfiguration) then,
  ) = _$AudioConfigurationCopyWithImpl<$Res, AudioConfiguration>;
  @useResult
  $Res call({
    int sampleRate,
    int channels,
    int bitRate,
    AudioQuality quality,
    AudioFormat format,
    bool enableNoiseReduction,
    bool enableEchoCancellation,
    bool enableAutomaticGainControl,
    double gainLevel,
    bool enableVoiceActivityDetection,
    double vadThreshold,
    int bufferSize,
    String? selectedDeviceId,
    bool enableRealTimeStreaming,
    int chunkDurationMs,
  });
}

/// @nodoc
class _$AudioConfigurationCopyWithImpl<$Res, $Val extends AudioConfiguration>
    implements $AudioConfigurationCopyWith<$Res> {
  _$AudioConfigurationCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of AudioConfiguration
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? sampleRate = null,
    Object? channels = null,
    Object? bitRate = null,
    Object? quality = null,
    Object? format = null,
    Object? enableNoiseReduction = null,
    Object? enableEchoCancellation = null,
    Object? enableAutomaticGainControl = null,
    Object? gainLevel = null,
    Object? enableVoiceActivityDetection = null,
    Object? vadThreshold = null,
    Object? bufferSize = null,
    Object? selectedDeviceId = freezed,
    Object? enableRealTimeStreaming = null,
    Object? chunkDurationMs = null,
  }) {
    return _then(
      _value.copyWith(
            sampleRate:
                null == sampleRate
                    ? _value.sampleRate
                    : sampleRate // ignore: cast_nullable_to_non_nullable
                        as int,
            channels:
                null == channels
                    ? _value.channels
                    : channels // ignore: cast_nullable_to_non_nullable
                        as int,
            bitRate:
                null == bitRate
                    ? _value.bitRate
                    : bitRate // ignore: cast_nullable_to_non_nullable
                        as int,
            quality:
                null == quality
                    ? _value.quality
                    : quality // ignore: cast_nullable_to_non_nullable
                        as AudioQuality,
            format:
                null == format
                    ? _value.format
                    : format // ignore: cast_nullable_to_non_nullable
                        as AudioFormat,
            enableNoiseReduction:
                null == enableNoiseReduction
                    ? _value.enableNoiseReduction
                    : enableNoiseReduction // ignore: cast_nullable_to_non_nullable
                        as bool,
            enableEchoCancellation:
                null == enableEchoCancellation
                    ? _value.enableEchoCancellation
                    : enableEchoCancellation // ignore: cast_nullable_to_non_nullable
                        as bool,
            enableAutomaticGainControl:
                null == enableAutomaticGainControl
                    ? _value.enableAutomaticGainControl
                    : enableAutomaticGainControl // ignore: cast_nullable_to_non_nullable
                        as bool,
            gainLevel:
                null == gainLevel
                    ? _value.gainLevel
                    : gainLevel // ignore: cast_nullable_to_non_nullable
                        as double,
            enableVoiceActivityDetection:
                null == enableVoiceActivityDetection
                    ? _value.enableVoiceActivityDetection
                    : enableVoiceActivityDetection // ignore: cast_nullable_to_non_nullable
                        as bool,
            vadThreshold:
                null == vadThreshold
                    ? _value.vadThreshold
                    : vadThreshold // ignore: cast_nullable_to_non_nullable
                        as double,
            bufferSize:
                null == bufferSize
                    ? _value.bufferSize
                    : bufferSize // ignore: cast_nullable_to_non_nullable
                        as int,
            selectedDeviceId:
                freezed == selectedDeviceId
                    ? _value.selectedDeviceId
                    : selectedDeviceId // ignore: cast_nullable_to_non_nullable
                        as String?,
            enableRealTimeStreaming:
                null == enableRealTimeStreaming
                    ? _value.enableRealTimeStreaming
                    : enableRealTimeStreaming // ignore: cast_nullable_to_non_nullable
                        as bool,
            chunkDurationMs:
                null == chunkDurationMs
                    ? _value.chunkDurationMs
                    : chunkDurationMs // ignore: cast_nullable_to_non_nullable
                        as int,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$AudioConfigurationImplCopyWith<$Res>
    implements $AudioConfigurationCopyWith<$Res> {
  factory _$$AudioConfigurationImplCopyWith(
    _$AudioConfigurationImpl value,
    $Res Function(_$AudioConfigurationImpl) then,
  ) = __$$AudioConfigurationImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    int sampleRate,
    int channels,
    int bitRate,
    AudioQuality quality,
    AudioFormat format,
    bool enableNoiseReduction,
    bool enableEchoCancellation,
    bool enableAutomaticGainControl,
    double gainLevel,
    bool enableVoiceActivityDetection,
    double vadThreshold,
    int bufferSize,
    String? selectedDeviceId,
    bool enableRealTimeStreaming,
    int chunkDurationMs,
  });
}

/// @nodoc
class __$$AudioConfigurationImplCopyWithImpl<$Res>
    extends _$AudioConfigurationCopyWithImpl<$Res, _$AudioConfigurationImpl>
    implements _$$AudioConfigurationImplCopyWith<$Res> {
  __$$AudioConfigurationImplCopyWithImpl(
    _$AudioConfigurationImpl _value,
    $Res Function(_$AudioConfigurationImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of AudioConfiguration
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? sampleRate = null,
    Object? channels = null,
    Object? bitRate = null,
    Object? quality = null,
    Object? format = null,
    Object? enableNoiseReduction = null,
    Object? enableEchoCancellation = null,
    Object? enableAutomaticGainControl = null,
    Object? gainLevel = null,
    Object? enableVoiceActivityDetection = null,
    Object? vadThreshold = null,
    Object? bufferSize = null,
    Object? selectedDeviceId = freezed,
    Object? enableRealTimeStreaming = null,
    Object? chunkDurationMs = null,
  }) {
    return _then(
      _$AudioConfigurationImpl(
        sampleRate:
            null == sampleRate
                ? _value.sampleRate
                : sampleRate // ignore: cast_nullable_to_non_nullable
                    as int,
        channels:
            null == channels
                ? _value.channels
                : channels // ignore: cast_nullable_to_non_nullable
                    as int,
        bitRate:
            null == bitRate
                ? _value.bitRate
                : bitRate // ignore: cast_nullable_to_non_nullable
                    as int,
        quality:
            null == quality
                ? _value.quality
                : quality // ignore: cast_nullable_to_non_nullable
                    as AudioQuality,
        format:
            null == format
                ? _value.format
                : format // ignore: cast_nullable_to_non_nullable
                    as AudioFormat,
        enableNoiseReduction:
            null == enableNoiseReduction
                ? _value.enableNoiseReduction
                : enableNoiseReduction // ignore: cast_nullable_to_non_nullable
                    as bool,
        enableEchoCancellation:
            null == enableEchoCancellation
                ? _value.enableEchoCancellation
                : enableEchoCancellation // ignore: cast_nullable_to_non_nullable
                    as bool,
        enableAutomaticGainControl:
            null == enableAutomaticGainControl
                ? _value.enableAutomaticGainControl
                : enableAutomaticGainControl // ignore: cast_nullable_to_non_nullable
                    as bool,
        gainLevel:
            null == gainLevel
                ? _value.gainLevel
                : gainLevel // ignore: cast_nullable_to_non_nullable
                    as double,
        enableVoiceActivityDetection:
            null == enableVoiceActivityDetection
                ? _value.enableVoiceActivityDetection
                : enableVoiceActivityDetection // ignore: cast_nullable_to_non_nullable
                    as bool,
        vadThreshold:
            null == vadThreshold
                ? _value.vadThreshold
                : vadThreshold // ignore: cast_nullable_to_non_nullable
                    as double,
        bufferSize:
            null == bufferSize
                ? _value.bufferSize
                : bufferSize // ignore: cast_nullable_to_non_nullable
                    as int,
        selectedDeviceId:
            freezed == selectedDeviceId
                ? _value.selectedDeviceId
                : selectedDeviceId // ignore: cast_nullable_to_non_nullable
                    as String?,
        enableRealTimeStreaming:
            null == enableRealTimeStreaming
                ? _value.enableRealTimeStreaming
                : enableRealTimeStreaming // ignore: cast_nullable_to_non_nullable
                    as bool,
        chunkDurationMs:
            null == chunkDurationMs
                ? _value.chunkDurationMs
                : chunkDurationMs // ignore: cast_nullable_to_non_nullable
                    as int,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$AudioConfigurationImpl implements _AudioConfiguration {
  const _$AudioConfigurationImpl({
    this.sampleRate = 16000,
    this.channels = 1,
    this.bitRate = 64000,
    this.quality = AudioQuality.medium,
    this.format = AudioFormat.wav,
    this.enableNoiseReduction = true,
    this.enableEchoCancellation = true,
    this.enableAutomaticGainControl = true,
    this.gainLevel = 1.0,
    this.enableVoiceActivityDetection = true,
    this.vadThreshold = 0.01,
    this.bufferSize = 4096,
    this.selectedDeviceId,
    this.enableRealTimeStreaming = true,
    this.chunkDurationMs = 100,
  });

  factory _$AudioConfigurationImpl.fromJson(Map<String, dynamic> json) =>
      _$$AudioConfigurationImplFromJson(json);

  /// Sample rate in Hz (e.g., 16000 for 16kHz)
  @override
  @JsonKey()
  final int sampleRate;

  /// Number of audio channels (1 for mono, 2 for stereo)
  @override
  @JsonKey()
  final int channels;

  /// Bit rate for encoding (in bits per second)
  @override
  @JsonKey()
  final int bitRate;

  /// Audio quality level
  @override
  @JsonKey()
  final AudioQuality quality;

  /// Audio format for recording
  @override
  @JsonKey()
  final AudioFormat format;

  /// Enable noise reduction
  @override
  @JsonKey()
  final bool enableNoiseReduction;

  /// Enable echo cancellation
  @override
  @JsonKey()
  final bool enableEchoCancellation;

  /// Enable automatic gain control
  @override
  @JsonKey()
  final bool enableAutomaticGainControl;

  /// Audio gain level (0.0 to 2.0, 1.0 is normal)
  @override
  @JsonKey()
  final double gainLevel;

  /// Enable voice activity detection
  @override
  @JsonKey()
  final bool enableVoiceActivityDetection;

  /// Voice activity detection threshold (0.0 to 1.0)
  @override
  @JsonKey()
  final double vadThreshold;

  /// Buffer size in frames for audio processing
  @override
  @JsonKey()
  final int bufferSize;

  /// Selected audio input device ID
  @override
  final String? selectedDeviceId;

  /// Enable real-time audio streaming
  @override
  @JsonKey()
  final bool enableRealTimeStreaming;

  /// Audio chunk duration for processing (in milliseconds)
  @override
  @JsonKey()
  final int chunkDurationMs;

  @override
  String toString() {
    return 'AudioConfiguration(sampleRate: $sampleRate, channels: $channels, bitRate: $bitRate, quality: $quality, format: $format, enableNoiseReduction: $enableNoiseReduction, enableEchoCancellation: $enableEchoCancellation, enableAutomaticGainControl: $enableAutomaticGainControl, gainLevel: $gainLevel, enableVoiceActivityDetection: $enableVoiceActivityDetection, vadThreshold: $vadThreshold, bufferSize: $bufferSize, selectedDeviceId: $selectedDeviceId, enableRealTimeStreaming: $enableRealTimeStreaming, chunkDurationMs: $chunkDurationMs)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$AudioConfigurationImpl &&
            (identical(other.sampleRate, sampleRate) ||
                other.sampleRate == sampleRate) &&
            (identical(other.channels, channels) ||
                other.channels == channels) &&
            (identical(other.bitRate, bitRate) || other.bitRate == bitRate) &&
            (identical(other.quality, quality) || other.quality == quality) &&
            (identical(other.format, format) || other.format == format) &&
            (identical(other.enableNoiseReduction, enableNoiseReduction) ||
                other.enableNoiseReduction == enableNoiseReduction) &&
            (identical(other.enableEchoCancellation, enableEchoCancellation) ||
                other.enableEchoCancellation == enableEchoCancellation) &&
            (identical(
                  other.enableAutomaticGainControl,
                  enableAutomaticGainControl,
                ) ||
                other.enableAutomaticGainControl ==
                    enableAutomaticGainControl) &&
            (identical(other.gainLevel, gainLevel) ||
                other.gainLevel == gainLevel) &&
            (identical(
                  other.enableVoiceActivityDetection,
                  enableVoiceActivityDetection,
                ) ||
                other.enableVoiceActivityDetection ==
                    enableVoiceActivityDetection) &&
            (identical(other.vadThreshold, vadThreshold) ||
                other.vadThreshold == vadThreshold) &&
            (identical(other.bufferSize, bufferSize) ||
                other.bufferSize == bufferSize) &&
            (identical(other.selectedDeviceId, selectedDeviceId) ||
                other.selectedDeviceId == selectedDeviceId) &&
            (identical(
                  other.enableRealTimeStreaming,
                  enableRealTimeStreaming,
                ) ||
                other.enableRealTimeStreaming == enableRealTimeStreaming) &&
            (identical(other.chunkDurationMs, chunkDurationMs) ||
                other.chunkDurationMs == chunkDurationMs));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    sampleRate,
    channels,
    bitRate,
    quality,
    format,
    enableNoiseReduction,
    enableEchoCancellation,
    enableAutomaticGainControl,
    gainLevel,
    enableVoiceActivityDetection,
    vadThreshold,
    bufferSize,
    selectedDeviceId,
    enableRealTimeStreaming,
    chunkDurationMs,
  );

  /// Create a copy of AudioConfiguration
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$AudioConfigurationImplCopyWith<_$AudioConfigurationImpl> get copyWith =>
      __$$AudioConfigurationImplCopyWithImpl<_$AudioConfigurationImpl>(
        this,
        _$identity,
      );

  @override
  Map<String, dynamic> toJson() {
    return _$$AudioConfigurationImplToJson(this);
  }
}

abstract class _AudioConfiguration implements AudioConfiguration {
  const factory _AudioConfiguration({
    final int sampleRate,
    final int channels,
    final int bitRate,
    final AudioQuality quality,
    final AudioFormat format,
    final bool enableNoiseReduction,
    final bool enableEchoCancellation,
    final bool enableAutomaticGainControl,
    final double gainLevel,
    final bool enableVoiceActivityDetection,
    final double vadThreshold,
    final int bufferSize,
    final String? selectedDeviceId,
    final bool enableRealTimeStreaming,
    final int chunkDurationMs,
  }) = _$AudioConfigurationImpl;

  factory _AudioConfiguration.fromJson(Map<String, dynamic> json) =
      _$AudioConfigurationImpl.fromJson;

  /// Sample rate in Hz (e.g., 16000 for 16kHz)
  @override
  int get sampleRate;

  /// Number of audio channels (1 for mono, 2 for stereo)
  @override
  int get channels;

  /// Bit rate for encoding (in bits per second)
  @override
  int get bitRate;

  /// Audio quality level
  @override
  AudioQuality get quality;

  /// Audio format for recording
  @override
  AudioFormat get format;

  /// Enable noise reduction
  @override
  bool get enableNoiseReduction;

  /// Enable echo cancellation
  @override
  bool get enableEchoCancellation;

  /// Enable automatic gain control
  @override
  bool get enableAutomaticGainControl;

  /// Audio gain level (0.0 to 2.0, 1.0 is normal)
  @override
  double get gainLevel;

  /// Enable voice activity detection
  @override
  bool get enableVoiceActivityDetection;

  /// Voice activity detection threshold (0.0 to 1.0)
  @override
  double get vadThreshold;

  /// Buffer size in frames for audio processing
  @override
  int get bufferSize;

  /// Selected audio input device ID
  @override
  String? get selectedDeviceId;

  /// Enable real-time audio streaming
  @override
  bool get enableRealTimeStreaming;

  /// Audio chunk duration for processing (in milliseconds)
  @override
  int get chunkDurationMs;

  /// Create a copy of AudioConfiguration
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$AudioConfigurationImplCopyWith<_$AudioConfigurationImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

AudioCapabilities _$AudioCapabilitiesFromJson(Map<String, dynamic> json) {
  return _AudioCapabilities.fromJson(json);
}

/// @nodoc
mixin _$AudioCapabilities {
  /// Supported sample rates
  List<int> get supportedSampleRates => throw _privateConstructorUsedError;

  /// Supported channel counts
  List<int> get supportedChannels => throw _privateConstructorUsedError;

  /// Supported audio formats
  List<AudioFormat> get supportedFormats => throw _privateConstructorUsedError;

  /// Whether noise reduction is supported
  bool get supportsNoiseReduction => throw _privateConstructorUsedError;

  /// Whether echo cancellation is supported
  bool get supportsEchoCancellation => throw _privateConstructorUsedError;

  /// Whether automatic gain control is supported
  bool get supportsAutomaticGainControl => throw _privateConstructorUsedError;

  /// Whether voice activity detection is supported
  bool get supportsVoiceActivityDetection => throw _privateConstructorUsedError;

  /// Maximum supported gain level
  double get maxGainLevel => throw _privateConstructorUsedError;

  /// Minimum supported gain level
  double get minGainLevel => throw _privateConstructorUsedError;

  /// Available buffer sizes
  List<int> get availableBufferSizes => throw _privateConstructorUsedError;

  /// Serializes this AudioCapabilities to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of AudioCapabilities
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $AudioCapabilitiesCopyWith<AudioCapabilities> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $AudioCapabilitiesCopyWith<$Res> {
  factory $AudioCapabilitiesCopyWith(
    AudioCapabilities value,
    $Res Function(AudioCapabilities) then,
  ) = _$AudioCapabilitiesCopyWithImpl<$Res, AudioCapabilities>;
  @useResult
  $Res call({
    List<int> supportedSampleRates,
    List<int> supportedChannels,
    List<AudioFormat> supportedFormats,
    bool supportsNoiseReduction,
    bool supportsEchoCancellation,
    bool supportsAutomaticGainControl,
    bool supportsVoiceActivityDetection,
    double maxGainLevel,
    double minGainLevel,
    List<int> availableBufferSizes,
  });
}

/// @nodoc
class _$AudioCapabilitiesCopyWithImpl<$Res, $Val extends AudioCapabilities>
    implements $AudioCapabilitiesCopyWith<$Res> {
  _$AudioCapabilitiesCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of AudioCapabilities
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? supportedSampleRates = null,
    Object? supportedChannels = null,
    Object? supportedFormats = null,
    Object? supportsNoiseReduction = null,
    Object? supportsEchoCancellation = null,
    Object? supportsAutomaticGainControl = null,
    Object? supportsVoiceActivityDetection = null,
    Object? maxGainLevel = null,
    Object? minGainLevel = null,
    Object? availableBufferSizes = null,
  }) {
    return _then(
      _value.copyWith(
            supportedSampleRates:
                null == supportedSampleRates
                    ? _value.supportedSampleRates
                    : supportedSampleRates // ignore: cast_nullable_to_non_nullable
                        as List<int>,
            supportedChannels:
                null == supportedChannels
                    ? _value.supportedChannels
                    : supportedChannels // ignore: cast_nullable_to_non_nullable
                        as List<int>,
            supportedFormats:
                null == supportedFormats
                    ? _value.supportedFormats
                    : supportedFormats // ignore: cast_nullable_to_non_nullable
                        as List<AudioFormat>,
            supportsNoiseReduction:
                null == supportsNoiseReduction
                    ? _value.supportsNoiseReduction
                    : supportsNoiseReduction // ignore: cast_nullable_to_non_nullable
                        as bool,
            supportsEchoCancellation:
                null == supportsEchoCancellation
                    ? _value.supportsEchoCancellation
                    : supportsEchoCancellation // ignore: cast_nullable_to_non_nullable
                        as bool,
            supportsAutomaticGainControl:
                null == supportsAutomaticGainControl
                    ? _value.supportsAutomaticGainControl
                    : supportsAutomaticGainControl // ignore: cast_nullable_to_non_nullable
                        as bool,
            supportsVoiceActivityDetection:
                null == supportsVoiceActivityDetection
                    ? _value.supportsVoiceActivityDetection
                    : supportsVoiceActivityDetection // ignore: cast_nullable_to_non_nullable
                        as bool,
            maxGainLevel:
                null == maxGainLevel
                    ? _value.maxGainLevel
                    : maxGainLevel // ignore: cast_nullable_to_non_nullable
                        as double,
            minGainLevel:
                null == minGainLevel
                    ? _value.minGainLevel
                    : minGainLevel // ignore: cast_nullable_to_non_nullable
                        as double,
            availableBufferSizes:
                null == availableBufferSizes
                    ? _value.availableBufferSizes
                    : availableBufferSizes // ignore: cast_nullable_to_non_nullable
                        as List<int>,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$AudioCapabilitiesImplCopyWith<$Res>
    implements $AudioCapabilitiesCopyWith<$Res> {
  factory _$$AudioCapabilitiesImplCopyWith(
    _$AudioCapabilitiesImpl value,
    $Res Function(_$AudioCapabilitiesImpl) then,
  ) = __$$AudioCapabilitiesImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    List<int> supportedSampleRates,
    List<int> supportedChannels,
    List<AudioFormat> supportedFormats,
    bool supportsNoiseReduction,
    bool supportsEchoCancellation,
    bool supportsAutomaticGainControl,
    bool supportsVoiceActivityDetection,
    double maxGainLevel,
    double minGainLevel,
    List<int> availableBufferSizes,
  });
}

/// @nodoc
class __$$AudioCapabilitiesImplCopyWithImpl<$Res>
    extends _$AudioCapabilitiesCopyWithImpl<$Res, _$AudioCapabilitiesImpl>
    implements _$$AudioCapabilitiesImplCopyWith<$Res> {
  __$$AudioCapabilitiesImplCopyWithImpl(
    _$AudioCapabilitiesImpl _value,
    $Res Function(_$AudioCapabilitiesImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of AudioCapabilities
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? supportedSampleRates = null,
    Object? supportedChannels = null,
    Object? supportedFormats = null,
    Object? supportsNoiseReduction = null,
    Object? supportsEchoCancellation = null,
    Object? supportsAutomaticGainControl = null,
    Object? supportsVoiceActivityDetection = null,
    Object? maxGainLevel = null,
    Object? minGainLevel = null,
    Object? availableBufferSizes = null,
  }) {
    return _then(
      _$AudioCapabilitiesImpl(
        supportedSampleRates:
            null == supportedSampleRates
                ? _value._supportedSampleRates
                : supportedSampleRates // ignore: cast_nullable_to_non_nullable
                    as List<int>,
        supportedChannels:
            null == supportedChannels
                ? _value._supportedChannels
                : supportedChannels // ignore: cast_nullable_to_non_nullable
                    as List<int>,
        supportedFormats:
            null == supportedFormats
                ? _value._supportedFormats
                : supportedFormats // ignore: cast_nullable_to_non_nullable
                    as List<AudioFormat>,
        supportsNoiseReduction:
            null == supportsNoiseReduction
                ? _value.supportsNoiseReduction
                : supportsNoiseReduction // ignore: cast_nullable_to_non_nullable
                    as bool,
        supportsEchoCancellation:
            null == supportsEchoCancellation
                ? _value.supportsEchoCancellation
                : supportsEchoCancellation // ignore: cast_nullable_to_non_nullable
                    as bool,
        supportsAutomaticGainControl:
            null == supportsAutomaticGainControl
                ? _value.supportsAutomaticGainControl
                : supportsAutomaticGainControl // ignore: cast_nullable_to_non_nullable
                    as bool,
        supportsVoiceActivityDetection:
            null == supportsVoiceActivityDetection
                ? _value.supportsVoiceActivityDetection
                : supportsVoiceActivityDetection // ignore: cast_nullable_to_non_nullable
                    as bool,
        maxGainLevel:
            null == maxGainLevel
                ? _value.maxGainLevel
                : maxGainLevel // ignore: cast_nullable_to_non_nullable
                    as double,
        minGainLevel:
            null == minGainLevel
                ? _value.minGainLevel
                : minGainLevel // ignore: cast_nullable_to_non_nullable
                    as double,
        availableBufferSizes:
            null == availableBufferSizes
                ? _value._availableBufferSizes
                : availableBufferSizes // ignore: cast_nullable_to_non_nullable
                    as List<int>,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$AudioCapabilitiesImpl implements _AudioCapabilities {
  const _$AudioCapabilitiesImpl({
    required final List<int> supportedSampleRates,
    required final List<int> supportedChannels,
    required final List<AudioFormat> supportedFormats,
    this.supportsNoiseReduction = false,
    this.supportsEchoCancellation = false,
    this.supportsAutomaticGainControl = false,
    this.supportsVoiceActivityDetection = false,
    this.maxGainLevel = 2.0,
    this.minGainLevel = 0.0,
    required final List<int> availableBufferSizes,
  }) : _supportedSampleRates = supportedSampleRates,
       _supportedChannels = supportedChannels,
       _supportedFormats = supportedFormats,
       _availableBufferSizes = availableBufferSizes;

  factory _$AudioCapabilitiesImpl.fromJson(Map<String, dynamic> json) =>
      _$$AudioCapabilitiesImplFromJson(json);

  /// Supported sample rates
  final List<int> _supportedSampleRates;

  /// Supported sample rates
  @override
  List<int> get supportedSampleRates {
    if (_supportedSampleRates is EqualUnmodifiableListView)
      return _supportedSampleRates;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_supportedSampleRates);
  }

  /// Supported channel counts
  final List<int> _supportedChannels;

  /// Supported channel counts
  @override
  List<int> get supportedChannels {
    if (_supportedChannels is EqualUnmodifiableListView)
      return _supportedChannels;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_supportedChannels);
  }

  /// Supported audio formats
  final List<AudioFormat> _supportedFormats;

  /// Supported audio formats
  @override
  List<AudioFormat> get supportedFormats {
    if (_supportedFormats is EqualUnmodifiableListView)
      return _supportedFormats;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_supportedFormats);
  }

  /// Whether noise reduction is supported
  @override
  @JsonKey()
  final bool supportsNoiseReduction;

  /// Whether echo cancellation is supported
  @override
  @JsonKey()
  final bool supportsEchoCancellation;

  /// Whether automatic gain control is supported
  @override
  @JsonKey()
  final bool supportsAutomaticGainControl;

  /// Whether voice activity detection is supported
  @override
  @JsonKey()
  final bool supportsVoiceActivityDetection;

  /// Maximum supported gain level
  @override
  @JsonKey()
  final double maxGainLevel;

  /// Minimum supported gain level
  @override
  @JsonKey()
  final double minGainLevel;

  /// Available buffer sizes
  final List<int> _availableBufferSizes;

  /// Available buffer sizes
  @override
  List<int> get availableBufferSizes {
    if (_availableBufferSizes is EqualUnmodifiableListView)
      return _availableBufferSizes;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_availableBufferSizes);
  }

  @override
  String toString() {
    return 'AudioCapabilities(supportedSampleRates: $supportedSampleRates, supportedChannels: $supportedChannels, supportedFormats: $supportedFormats, supportsNoiseReduction: $supportsNoiseReduction, supportsEchoCancellation: $supportsEchoCancellation, supportsAutomaticGainControl: $supportsAutomaticGainControl, supportsVoiceActivityDetection: $supportsVoiceActivityDetection, maxGainLevel: $maxGainLevel, minGainLevel: $minGainLevel, availableBufferSizes: $availableBufferSizes)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$AudioCapabilitiesImpl &&
            const DeepCollectionEquality().equals(
              other._supportedSampleRates,
              _supportedSampleRates,
            ) &&
            const DeepCollectionEquality().equals(
              other._supportedChannels,
              _supportedChannels,
            ) &&
            const DeepCollectionEquality().equals(
              other._supportedFormats,
              _supportedFormats,
            ) &&
            (identical(other.supportsNoiseReduction, supportsNoiseReduction) ||
                other.supportsNoiseReduction == supportsNoiseReduction) &&
            (identical(
                  other.supportsEchoCancellation,
                  supportsEchoCancellation,
                ) ||
                other.supportsEchoCancellation == supportsEchoCancellation) &&
            (identical(
                  other.supportsAutomaticGainControl,
                  supportsAutomaticGainControl,
                ) ||
                other.supportsAutomaticGainControl ==
                    supportsAutomaticGainControl) &&
            (identical(
                  other.supportsVoiceActivityDetection,
                  supportsVoiceActivityDetection,
                ) ||
                other.supportsVoiceActivityDetection ==
                    supportsVoiceActivityDetection) &&
            (identical(other.maxGainLevel, maxGainLevel) ||
                other.maxGainLevel == maxGainLevel) &&
            (identical(other.minGainLevel, minGainLevel) ||
                other.minGainLevel == minGainLevel) &&
            const DeepCollectionEquality().equals(
              other._availableBufferSizes,
              _availableBufferSizes,
            ));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    const DeepCollectionEquality().hash(_supportedSampleRates),
    const DeepCollectionEquality().hash(_supportedChannels),
    const DeepCollectionEquality().hash(_supportedFormats),
    supportsNoiseReduction,
    supportsEchoCancellation,
    supportsAutomaticGainControl,
    supportsVoiceActivityDetection,
    maxGainLevel,
    minGainLevel,
    const DeepCollectionEquality().hash(_availableBufferSizes),
  );

  /// Create a copy of AudioCapabilities
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$AudioCapabilitiesImplCopyWith<_$AudioCapabilitiesImpl> get copyWith =>
      __$$AudioCapabilitiesImplCopyWithImpl<_$AudioCapabilitiesImpl>(
        this,
        _$identity,
      );

  @override
  Map<String, dynamic> toJson() {
    return _$$AudioCapabilitiesImplToJson(this);
  }
}

abstract class _AudioCapabilities implements AudioCapabilities {
  const factory _AudioCapabilities({
    required final List<int> supportedSampleRates,
    required final List<int> supportedChannels,
    required final List<AudioFormat> supportedFormats,
    final bool supportsNoiseReduction,
    final bool supportsEchoCancellation,
    final bool supportsAutomaticGainControl,
    final bool supportsVoiceActivityDetection,
    final double maxGainLevel,
    final double minGainLevel,
    required final List<int> availableBufferSizes,
  }) = _$AudioCapabilitiesImpl;

  factory _AudioCapabilities.fromJson(Map<String, dynamic> json) =
      _$AudioCapabilitiesImpl.fromJson;

  /// Supported sample rates
  @override
  List<int> get supportedSampleRates;

  /// Supported channel counts
  @override
  List<int> get supportedChannels;

  /// Supported audio formats
  @override
  List<AudioFormat> get supportedFormats;

  /// Whether noise reduction is supported
  @override
  bool get supportsNoiseReduction;

  /// Whether echo cancellation is supported
  @override
  bool get supportsEchoCancellation;

  /// Whether automatic gain control is supported
  @override
  bool get supportsAutomaticGainControl;

  /// Whether voice activity detection is supported
  @override
  bool get supportsVoiceActivityDetection;

  /// Maximum supported gain level
  @override
  double get maxGainLevel;

  /// Minimum supported gain level
  @override
  double get minGainLevel;

  /// Available buffer sizes
  @override
  List<int> get availableBufferSizes;

  /// Create a copy of AudioCapabilities
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$AudioCapabilitiesImplCopyWith<_$AudioCapabilitiesImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
