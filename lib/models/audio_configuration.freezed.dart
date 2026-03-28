// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'audio_configuration.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$AudioConfiguration {

/// Sample rate in Hz (e.g., 16000 for 16kHz)
 int get sampleRate;/// Number of audio channels (1 for mono, 2 for stereo)
 int get channels;/// Bit rate for encoding (in bits per second)
 int get bitRate;/// Audio quality level
 AudioQuality get quality;/// Audio format for recording
 AudioFormat get format;/// Enable noise reduction
 bool get enableNoiseReduction;/// Enable echo cancellation
 bool get enableEchoCancellation;/// Enable automatic gain control
 bool get enableAutomaticGainControl;/// Audio gain level (0.0 to 2.0, 1.0 is normal)
 double get gainLevel;/// Enable voice activity detection
 bool get enableVoiceActivityDetection;/// Voice activity detection threshold (0.0 to 1.0)
 double get vadThreshold;/// Buffer size in frames for audio processing
 int get bufferSize;/// Selected audio input device ID
 String? get selectedDeviceId;/// Enable real-time audio streaming
 bool get enableRealTimeStreaming;/// Audio chunk duration for processing (in milliseconds)
 int get chunkDurationMs;
/// Create a copy of AudioConfiguration
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AudioConfigurationCopyWith<AudioConfiguration> get copyWith => _$AudioConfigurationCopyWithImpl<AudioConfiguration>(this as AudioConfiguration, _$identity);

  /// Serializes this AudioConfiguration to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AudioConfiguration&&(identical(other.sampleRate, sampleRate) || other.sampleRate == sampleRate)&&(identical(other.channels, channels) || other.channels == channels)&&(identical(other.bitRate, bitRate) || other.bitRate == bitRate)&&(identical(other.quality, quality) || other.quality == quality)&&(identical(other.format, format) || other.format == format)&&(identical(other.enableNoiseReduction, enableNoiseReduction) || other.enableNoiseReduction == enableNoiseReduction)&&(identical(other.enableEchoCancellation, enableEchoCancellation) || other.enableEchoCancellation == enableEchoCancellation)&&(identical(other.enableAutomaticGainControl, enableAutomaticGainControl) || other.enableAutomaticGainControl == enableAutomaticGainControl)&&(identical(other.gainLevel, gainLevel) || other.gainLevel == gainLevel)&&(identical(other.enableVoiceActivityDetection, enableVoiceActivityDetection) || other.enableVoiceActivityDetection == enableVoiceActivityDetection)&&(identical(other.vadThreshold, vadThreshold) || other.vadThreshold == vadThreshold)&&(identical(other.bufferSize, bufferSize) || other.bufferSize == bufferSize)&&(identical(other.selectedDeviceId, selectedDeviceId) || other.selectedDeviceId == selectedDeviceId)&&(identical(other.enableRealTimeStreaming, enableRealTimeStreaming) || other.enableRealTimeStreaming == enableRealTimeStreaming)&&(identical(other.chunkDurationMs, chunkDurationMs) || other.chunkDurationMs == chunkDurationMs));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,sampleRate,channels,bitRate,quality,format,enableNoiseReduction,enableEchoCancellation,enableAutomaticGainControl,gainLevel,enableVoiceActivityDetection,vadThreshold,bufferSize,selectedDeviceId,enableRealTimeStreaming,chunkDurationMs);

@override
String toString() {
  return 'AudioConfiguration(sampleRate: $sampleRate, channels: $channels, bitRate: $bitRate, quality: $quality, format: $format, enableNoiseReduction: $enableNoiseReduction, enableEchoCancellation: $enableEchoCancellation, enableAutomaticGainControl: $enableAutomaticGainControl, gainLevel: $gainLevel, enableVoiceActivityDetection: $enableVoiceActivityDetection, vadThreshold: $vadThreshold, bufferSize: $bufferSize, selectedDeviceId: $selectedDeviceId, enableRealTimeStreaming: $enableRealTimeStreaming, chunkDurationMs: $chunkDurationMs)';
}


}

/// @nodoc
abstract mixin class $AudioConfigurationCopyWith<$Res>  {
  factory $AudioConfigurationCopyWith(AudioConfiguration value, $Res Function(AudioConfiguration) _then) = _$AudioConfigurationCopyWithImpl;
@useResult
$Res call({
 int sampleRate, int channels, int bitRate, AudioQuality quality, AudioFormat format, bool enableNoiseReduction, bool enableEchoCancellation, bool enableAutomaticGainControl, double gainLevel, bool enableVoiceActivityDetection, double vadThreshold, int bufferSize, String? selectedDeviceId, bool enableRealTimeStreaming, int chunkDurationMs
});




}
/// @nodoc
class _$AudioConfigurationCopyWithImpl<$Res>
    implements $AudioConfigurationCopyWith<$Res> {
  _$AudioConfigurationCopyWithImpl(this._self, this._then);

  final AudioConfiguration _self;
  final $Res Function(AudioConfiguration) _then;

/// Create a copy of AudioConfiguration
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? sampleRate = null,Object? channels = null,Object? bitRate = null,Object? quality = null,Object? format = null,Object? enableNoiseReduction = null,Object? enableEchoCancellation = null,Object? enableAutomaticGainControl = null,Object? gainLevel = null,Object? enableVoiceActivityDetection = null,Object? vadThreshold = null,Object? bufferSize = null,Object? selectedDeviceId = freezed,Object? enableRealTimeStreaming = null,Object? chunkDurationMs = null,}) {
  return _then(_self.copyWith(
sampleRate: null == sampleRate ? _self.sampleRate : sampleRate // ignore: cast_nullable_to_non_nullable
as int,channels: null == channels ? _self.channels : channels // ignore: cast_nullable_to_non_nullable
as int,bitRate: null == bitRate ? _self.bitRate : bitRate // ignore: cast_nullable_to_non_nullable
as int,quality: null == quality ? _self.quality : quality // ignore: cast_nullable_to_non_nullable
as AudioQuality,format: null == format ? _self.format : format // ignore: cast_nullable_to_non_nullable
as AudioFormat,enableNoiseReduction: null == enableNoiseReduction ? _self.enableNoiseReduction : enableNoiseReduction // ignore: cast_nullable_to_non_nullable
as bool,enableEchoCancellation: null == enableEchoCancellation ? _self.enableEchoCancellation : enableEchoCancellation // ignore: cast_nullable_to_non_nullable
as bool,enableAutomaticGainControl: null == enableAutomaticGainControl ? _self.enableAutomaticGainControl : enableAutomaticGainControl // ignore: cast_nullable_to_non_nullable
as bool,gainLevel: null == gainLevel ? _self.gainLevel : gainLevel // ignore: cast_nullable_to_non_nullable
as double,enableVoiceActivityDetection: null == enableVoiceActivityDetection ? _self.enableVoiceActivityDetection : enableVoiceActivityDetection // ignore: cast_nullable_to_non_nullable
as bool,vadThreshold: null == vadThreshold ? _self.vadThreshold : vadThreshold // ignore: cast_nullable_to_non_nullable
as double,bufferSize: null == bufferSize ? _self.bufferSize : bufferSize // ignore: cast_nullable_to_non_nullable
as int,selectedDeviceId: freezed == selectedDeviceId ? _self.selectedDeviceId : selectedDeviceId // ignore: cast_nullable_to_non_nullable
as String?,enableRealTimeStreaming: null == enableRealTimeStreaming ? _self.enableRealTimeStreaming : enableRealTimeStreaming // ignore: cast_nullable_to_non_nullable
as bool,chunkDurationMs: null == chunkDurationMs ? _self.chunkDurationMs : chunkDurationMs // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [AudioConfiguration].
extension AudioConfigurationPatterns on AudioConfiguration {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _AudioConfiguration value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _AudioConfiguration() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _AudioConfiguration value)  $default,){
final _that = this;
switch (_that) {
case _AudioConfiguration():
return $default(_that);}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _AudioConfiguration value)?  $default,){
final _that = this;
switch (_that) {
case _AudioConfiguration() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int sampleRate,  int channels,  int bitRate,  AudioQuality quality,  AudioFormat format,  bool enableNoiseReduction,  bool enableEchoCancellation,  bool enableAutomaticGainControl,  double gainLevel,  bool enableVoiceActivityDetection,  double vadThreshold,  int bufferSize,  String? selectedDeviceId,  bool enableRealTimeStreaming,  int chunkDurationMs)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _AudioConfiguration() when $default != null:
return $default(_that.sampleRate,_that.channels,_that.bitRate,_that.quality,_that.format,_that.enableNoiseReduction,_that.enableEchoCancellation,_that.enableAutomaticGainControl,_that.gainLevel,_that.enableVoiceActivityDetection,_that.vadThreshold,_that.bufferSize,_that.selectedDeviceId,_that.enableRealTimeStreaming,_that.chunkDurationMs);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int sampleRate,  int channels,  int bitRate,  AudioQuality quality,  AudioFormat format,  bool enableNoiseReduction,  bool enableEchoCancellation,  bool enableAutomaticGainControl,  double gainLevel,  bool enableVoiceActivityDetection,  double vadThreshold,  int bufferSize,  String? selectedDeviceId,  bool enableRealTimeStreaming,  int chunkDurationMs)  $default,) {final _that = this;
switch (_that) {
case _AudioConfiguration():
return $default(_that.sampleRate,_that.channels,_that.bitRate,_that.quality,_that.format,_that.enableNoiseReduction,_that.enableEchoCancellation,_that.enableAutomaticGainControl,_that.gainLevel,_that.enableVoiceActivityDetection,_that.vadThreshold,_that.bufferSize,_that.selectedDeviceId,_that.enableRealTimeStreaming,_that.chunkDurationMs);}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int sampleRate,  int channels,  int bitRate,  AudioQuality quality,  AudioFormat format,  bool enableNoiseReduction,  bool enableEchoCancellation,  bool enableAutomaticGainControl,  double gainLevel,  bool enableVoiceActivityDetection,  double vadThreshold,  int bufferSize,  String? selectedDeviceId,  bool enableRealTimeStreaming,  int chunkDurationMs)?  $default,) {final _that = this;
switch (_that) {
case _AudioConfiguration() when $default != null:
return $default(_that.sampleRate,_that.channels,_that.bitRate,_that.quality,_that.format,_that.enableNoiseReduction,_that.enableEchoCancellation,_that.enableAutomaticGainControl,_that.gainLevel,_that.enableVoiceActivityDetection,_that.vadThreshold,_that.bufferSize,_that.selectedDeviceId,_that.enableRealTimeStreaming,_that.chunkDurationMs);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _AudioConfiguration implements AudioConfiguration {
  const _AudioConfiguration({this.sampleRate = 16000, this.channels = 1, this.bitRate = 64000, this.quality = AudioQuality.medium, this.format = AudioFormat.wav, this.enableNoiseReduction = true, this.enableEchoCancellation = true, this.enableAutomaticGainControl = true, this.gainLevel = 1.0, this.enableVoiceActivityDetection = true, this.vadThreshold = 0.01, this.bufferSize = 4096, this.selectedDeviceId, this.enableRealTimeStreaming = true, this.chunkDurationMs = 100});
  factory _AudioConfiguration.fromJson(Map<String, dynamic> json) => _$AudioConfigurationFromJson(json);

/// Sample rate in Hz (e.g., 16000 for 16kHz)
@override@JsonKey() final  int sampleRate;
/// Number of audio channels (1 for mono, 2 for stereo)
@override@JsonKey() final  int channels;
/// Bit rate for encoding (in bits per second)
@override@JsonKey() final  int bitRate;
/// Audio quality level
@override@JsonKey() final  AudioQuality quality;
/// Audio format for recording
@override@JsonKey() final  AudioFormat format;
/// Enable noise reduction
@override@JsonKey() final  bool enableNoiseReduction;
/// Enable echo cancellation
@override@JsonKey() final  bool enableEchoCancellation;
/// Enable automatic gain control
@override@JsonKey() final  bool enableAutomaticGainControl;
/// Audio gain level (0.0 to 2.0, 1.0 is normal)
@override@JsonKey() final  double gainLevel;
/// Enable voice activity detection
@override@JsonKey() final  bool enableVoiceActivityDetection;
/// Voice activity detection threshold (0.0 to 1.0)
@override@JsonKey() final  double vadThreshold;
/// Buffer size in frames for audio processing
@override@JsonKey() final  int bufferSize;
/// Selected audio input device ID
@override final  String? selectedDeviceId;
/// Enable real-time audio streaming
@override@JsonKey() final  bool enableRealTimeStreaming;
/// Audio chunk duration for processing (in milliseconds)
@override@JsonKey() final  int chunkDurationMs;

/// Create a copy of AudioConfiguration
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$AudioConfigurationCopyWith<_AudioConfiguration> get copyWith => __$AudioConfigurationCopyWithImpl<_AudioConfiguration>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$AudioConfigurationToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _AudioConfiguration&&(identical(other.sampleRate, sampleRate) || other.sampleRate == sampleRate)&&(identical(other.channels, channels) || other.channels == channels)&&(identical(other.bitRate, bitRate) || other.bitRate == bitRate)&&(identical(other.quality, quality) || other.quality == quality)&&(identical(other.format, format) || other.format == format)&&(identical(other.enableNoiseReduction, enableNoiseReduction) || other.enableNoiseReduction == enableNoiseReduction)&&(identical(other.enableEchoCancellation, enableEchoCancellation) || other.enableEchoCancellation == enableEchoCancellation)&&(identical(other.enableAutomaticGainControl, enableAutomaticGainControl) || other.enableAutomaticGainControl == enableAutomaticGainControl)&&(identical(other.gainLevel, gainLevel) || other.gainLevel == gainLevel)&&(identical(other.enableVoiceActivityDetection, enableVoiceActivityDetection) || other.enableVoiceActivityDetection == enableVoiceActivityDetection)&&(identical(other.vadThreshold, vadThreshold) || other.vadThreshold == vadThreshold)&&(identical(other.bufferSize, bufferSize) || other.bufferSize == bufferSize)&&(identical(other.selectedDeviceId, selectedDeviceId) || other.selectedDeviceId == selectedDeviceId)&&(identical(other.enableRealTimeStreaming, enableRealTimeStreaming) || other.enableRealTimeStreaming == enableRealTimeStreaming)&&(identical(other.chunkDurationMs, chunkDurationMs) || other.chunkDurationMs == chunkDurationMs));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,sampleRate,channels,bitRate,quality,format,enableNoiseReduction,enableEchoCancellation,enableAutomaticGainControl,gainLevel,enableVoiceActivityDetection,vadThreshold,bufferSize,selectedDeviceId,enableRealTimeStreaming,chunkDurationMs);

@override
String toString() {
  return 'AudioConfiguration(sampleRate: $sampleRate, channels: $channels, bitRate: $bitRate, quality: $quality, format: $format, enableNoiseReduction: $enableNoiseReduction, enableEchoCancellation: $enableEchoCancellation, enableAutomaticGainControl: $enableAutomaticGainControl, gainLevel: $gainLevel, enableVoiceActivityDetection: $enableVoiceActivityDetection, vadThreshold: $vadThreshold, bufferSize: $bufferSize, selectedDeviceId: $selectedDeviceId, enableRealTimeStreaming: $enableRealTimeStreaming, chunkDurationMs: $chunkDurationMs)';
}


}

/// @nodoc
abstract mixin class _$AudioConfigurationCopyWith<$Res> implements $AudioConfigurationCopyWith<$Res> {
  factory _$AudioConfigurationCopyWith(_AudioConfiguration value, $Res Function(_AudioConfiguration) _then) = __$AudioConfigurationCopyWithImpl;
@override @useResult
$Res call({
 int sampleRate, int channels, int bitRate, AudioQuality quality, AudioFormat format, bool enableNoiseReduction, bool enableEchoCancellation, bool enableAutomaticGainControl, double gainLevel, bool enableVoiceActivityDetection, double vadThreshold, int bufferSize, String? selectedDeviceId, bool enableRealTimeStreaming, int chunkDurationMs
});




}
/// @nodoc
class __$AudioConfigurationCopyWithImpl<$Res>
    implements _$AudioConfigurationCopyWith<$Res> {
  __$AudioConfigurationCopyWithImpl(this._self, this._then);

  final _AudioConfiguration _self;
  final $Res Function(_AudioConfiguration) _then;

/// Create a copy of AudioConfiguration
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? sampleRate = null,Object? channels = null,Object? bitRate = null,Object? quality = null,Object? format = null,Object? enableNoiseReduction = null,Object? enableEchoCancellation = null,Object? enableAutomaticGainControl = null,Object? gainLevel = null,Object? enableVoiceActivityDetection = null,Object? vadThreshold = null,Object? bufferSize = null,Object? selectedDeviceId = freezed,Object? enableRealTimeStreaming = null,Object? chunkDurationMs = null,}) {
  return _then(_AudioConfiguration(
sampleRate: null == sampleRate ? _self.sampleRate : sampleRate // ignore: cast_nullable_to_non_nullable
as int,channels: null == channels ? _self.channels : channels // ignore: cast_nullable_to_non_nullable
as int,bitRate: null == bitRate ? _self.bitRate : bitRate // ignore: cast_nullable_to_non_nullable
as int,quality: null == quality ? _self.quality : quality // ignore: cast_nullable_to_non_nullable
as AudioQuality,format: null == format ? _self.format : format // ignore: cast_nullable_to_non_nullable
as AudioFormat,enableNoiseReduction: null == enableNoiseReduction ? _self.enableNoiseReduction : enableNoiseReduction // ignore: cast_nullable_to_non_nullable
as bool,enableEchoCancellation: null == enableEchoCancellation ? _self.enableEchoCancellation : enableEchoCancellation // ignore: cast_nullable_to_non_nullable
as bool,enableAutomaticGainControl: null == enableAutomaticGainControl ? _self.enableAutomaticGainControl : enableAutomaticGainControl // ignore: cast_nullable_to_non_nullable
as bool,gainLevel: null == gainLevel ? _self.gainLevel : gainLevel // ignore: cast_nullable_to_non_nullable
as double,enableVoiceActivityDetection: null == enableVoiceActivityDetection ? _self.enableVoiceActivityDetection : enableVoiceActivityDetection // ignore: cast_nullable_to_non_nullable
as bool,vadThreshold: null == vadThreshold ? _self.vadThreshold : vadThreshold // ignore: cast_nullable_to_non_nullable
as double,bufferSize: null == bufferSize ? _self.bufferSize : bufferSize // ignore: cast_nullable_to_non_nullable
as int,selectedDeviceId: freezed == selectedDeviceId ? _self.selectedDeviceId : selectedDeviceId // ignore: cast_nullable_to_non_nullable
as String?,enableRealTimeStreaming: null == enableRealTimeStreaming ? _self.enableRealTimeStreaming : enableRealTimeStreaming // ignore: cast_nullable_to_non_nullable
as bool,chunkDurationMs: null == chunkDurationMs ? _self.chunkDurationMs : chunkDurationMs // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}


/// @nodoc
mixin _$AudioCapabilities {

/// Supported sample rates
 List<int> get supportedSampleRates;/// Supported channel counts
 List<int> get supportedChannels;/// Supported audio formats
 List<AudioFormat> get supportedFormats;/// Whether noise reduction is supported
 bool get supportsNoiseReduction;/// Whether echo cancellation is supported
 bool get supportsEchoCancellation;/// Whether automatic gain control is supported
 bool get supportsAutomaticGainControl;/// Whether voice activity detection is supported
 bool get supportsVoiceActivityDetection;/// Maximum supported gain level
 double get maxGainLevel;/// Minimum supported gain level
 double get minGainLevel;/// Available buffer sizes
 List<int> get availableBufferSizes;
/// Create a copy of AudioCapabilities
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AudioCapabilitiesCopyWith<AudioCapabilities> get copyWith => _$AudioCapabilitiesCopyWithImpl<AudioCapabilities>(this as AudioCapabilities, _$identity);

  /// Serializes this AudioCapabilities to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AudioCapabilities&&const DeepCollectionEquality().equals(other.supportedSampleRates, supportedSampleRates)&&const DeepCollectionEquality().equals(other.supportedChannels, supportedChannels)&&const DeepCollectionEquality().equals(other.supportedFormats, supportedFormats)&&(identical(other.supportsNoiseReduction, supportsNoiseReduction) || other.supportsNoiseReduction == supportsNoiseReduction)&&(identical(other.supportsEchoCancellation, supportsEchoCancellation) || other.supportsEchoCancellation == supportsEchoCancellation)&&(identical(other.supportsAutomaticGainControl, supportsAutomaticGainControl) || other.supportsAutomaticGainControl == supportsAutomaticGainControl)&&(identical(other.supportsVoiceActivityDetection, supportsVoiceActivityDetection) || other.supportsVoiceActivityDetection == supportsVoiceActivityDetection)&&(identical(other.maxGainLevel, maxGainLevel) || other.maxGainLevel == maxGainLevel)&&(identical(other.minGainLevel, minGainLevel) || other.minGainLevel == minGainLevel)&&const DeepCollectionEquality().equals(other.availableBufferSizes, availableBufferSizes));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(supportedSampleRates),const DeepCollectionEquality().hash(supportedChannels),const DeepCollectionEquality().hash(supportedFormats),supportsNoiseReduction,supportsEchoCancellation,supportsAutomaticGainControl,supportsVoiceActivityDetection,maxGainLevel,minGainLevel,const DeepCollectionEquality().hash(availableBufferSizes));

@override
String toString() {
  return 'AudioCapabilities(supportedSampleRates: $supportedSampleRates, supportedChannels: $supportedChannels, supportedFormats: $supportedFormats, supportsNoiseReduction: $supportsNoiseReduction, supportsEchoCancellation: $supportsEchoCancellation, supportsAutomaticGainControl: $supportsAutomaticGainControl, supportsVoiceActivityDetection: $supportsVoiceActivityDetection, maxGainLevel: $maxGainLevel, minGainLevel: $minGainLevel, availableBufferSizes: $availableBufferSizes)';
}


}

/// @nodoc
abstract mixin class $AudioCapabilitiesCopyWith<$Res>  {
  factory $AudioCapabilitiesCopyWith(AudioCapabilities value, $Res Function(AudioCapabilities) _then) = _$AudioCapabilitiesCopyWithImpl;
@useResult
$Res call({
 List<int> supportedSampleRates, List<int> supportedChannels, List<AudioFormat> supportedFormats, bool supportsNoiseReduction, bool supportsEchoCancellation, bool supportsAutomaticGainControl, bool supportsVoiceActivityDetection, double maxGainLevel, double minGainLevel, List<int> availableBufferSizes
});




}
/// @nodoc
class _$AudioCapabilitiesCopyWithImpl<$Res>
    implements $AudioCapabilitiesCopyWith<$Res> {
  _$AudioCapabilitiesCopyWithImpl(this._self, this._then);

  final AudioCapabilities _self;
  final $Res Function(AudioCapabilities) _then;

/// Create a copy of AudioCapabilities
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? supportedSampleRates = null,Object? supportedChannels = null,Object? supportedFormats = null,Object? supportsNoiseReduction = null,Object? supportsEchoCancellation = null,Object? supportsAutomaticGainControl = null,Object? supportsVoiceActivityDetection = null,Object? maxGainLevel = null,Object? minGainLevel = null,Object? availableBufferSizes = null,}) {
  return _then(_self.copyWith(
supportedSampleRates: null == supportedSampleRates ? _self.supportedSampleRates : supportedSampleRates // ignore: cast_nullable_to_non_nullable
as List<int>,supportedChannels: null == supportedChannels ? _self.supportedChannels : supportedChannels // ignore: cast_nullable_to_non_nullable
as List<int>,supportedFormats: null == supportedFormats ? _self.supportedFormats : supportedFormats // ignore: cast_nullable_to_non_nullable
as List<AudioFormat>,supportsNoiseReduction: null == supportsNoiseReduction ? _self.supportsNoiseReduction : supportsNoiseReduction // ignore: cast_nullable_to_non_nullable
as bool,supportsEchoCancellation: null == supportsEchoCancellation ? _self.supportsEchoCancellation : supportsEchoCancellation // ignore: cast_nullable_to_non_nullable
as bool,supportsAutomaticGainControl: null == supportsAutomaticGainControl ? _self.supportsAutomaticGainControl : supportsAutomaticGainControl // ignore: cast_nullable_to_non_nullable
as bool,supportsVoiceActivityDetection: null == supportsVoiceActivityDetection ? _self.supportsVoiceActivityDetection : supportsVoiceActivityDetection // ignore: cast_nullable_to_non_nullable
as bool,maxGainLevel: null == maxGainLevel ? _self.maxGainLevel : maxGainLevel // ignore: cast_nullable_to_non_nullable
as double,minGainLevel: null == minGainLevel ? _self.minGainLevel : minGainLevel // ignore: cast_nullable_to_non_nullable
as double,availableBufferSizes: null == availableBufferSizes ? _self.availableBufferSizes : availableBufferSizes // ignore: cast_nullable_to_non_nullable
as List<int>,
  ));
}

}


/// Adds pattern-matching-related methods to [AudioCapabilities].
extension AudioCapabilitiesPatterns on AudioCapabilities {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _AudioCapabilities value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _AudioCapabilities() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _AudioCapabilities value)  $default,){
final _that = this;
switch (_that) {
case _AudioCapabilities():
return $default(_that);}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _AudioCapabilities value)?  $default,){
final _that = this;
switch (_that) {
case _AudioCapabilities() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( List<int> supportedSampleRates,  List<int> supportedChannels,  List<AudioFormat> supportedFormats,  bool supportsNoiseReduction,  bool supportsEchoCancellation,  bool supportsAutomaticGainControl,  bool supportsVoiceActivityDetection,  double maxGainLevel,  double minGainLevel,  List<int> availableBufferSizes)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _AudioCapabilities() when $default != null:
return $default(_that.supportedSampleRates,_that.supportedChannels,_that.supportedFormats,_that.supportsNoiseReduction,_that.supportsEchoCancellation,_that.supportsAutomaticGainControl,_that.supportsVoiceActivityDetection,_that.maxGainLevel,_that.minGainLevel,_that.availableBufferSizes);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( List<int> supportedSampleRates,  List<int> supportedChannels,  List<AudioFormat> supportedFormats,  bool supportsNoiseReduction,  bool supportsEchoCancellation,  bool supportsAutomaticGainControl,  bool supportsVoiceActivityDetection,  double maxGainLevel,  double minGainLevel,  List<int> availableBufferSizes)  $default,) {final _that = this;
switch (_that) {
case _AudioCapabilities():
return $default(_that.supportedSampleRates,_that.supportedChannels,_that.supportedFormats,_that.supportsNoiseReduction,_that.supportsEchoCancellation,_that.supportsAutomaticGainControl,_that.supportsVoiceActivityDetection,_that.maxGainLevel,_that.minGainLevel,_that.availableBufferSizes);}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( List<int> supportedSampleRates,  List<int> supportedChannels,  List<AudioFormat> supportedFormats,  bool supportsNoiseReduction,  bool supportsEchoCancellation,  bool supportsAutomaticGainControl,  bool supportsVoiceActivityDetection,  double maxGainLevel,  double minGainLevel,  List<int> availableBufferSizes)?  $default,) {final _that = this;
switch (_that) {
case _AudioCapabilities() when $default != null:
return $default(_that.supportedSampleRates,_that.supportedChannels,_that.supportedFormats,_that.supportsNoiseReduction,_that.supportsEchoCancellation,_that.supportsAutomaticGainControl,_that.supportsVoiceActivityDetection,_that.maxGainLevel,_that.minGainLevel,_that.availableBufferSizes);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _AudioCapabilities implements AudioCapabilities {
  const _AudioCapabilities({required final  List<int> supportedSampleRates, required final  List<int> supportedChannels, required final  List<AudioFormat> supportedFormats, this.supportsNoiseReduction = false, this.supportsEchoCancellation = false, this.supportsAutomaticGainControl = false, this.supportsVoiceActivityDetection = false, this.maxGainLevel = 2.0, this.minGainLevel = 0.0, required final  List<int> availableBufferSizes}): _supportedSampleRates = supportedSampleRates,_supportedChannels = supportedChannels,_supportedFormats = supportedFormats,_availableBufferSizes = availableBufferSizes;
  factory _AudioCapabilities.fromJson(Map<String, dynamic> json) => _$AudioCapabilitiesFromJson(json);

/// Supported sample rates
 final  List<int> _supportedSampleRates;
/// Supported sample rates
@override List<int> get supportedSampleRates {
  if (_supportedSampleRates is EqualUnmodifiableListView) return _supportedSampleRates;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_supportedSampleRates);
}

/// Supported channel counts
 final  List<int> _supportedChannels;
/// Supported channel counts
@override List<int> get supportedChannels {
  if (_supportedChannels is EqualUnmodifiableListView) return _supportedChannels;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_supportedChannels);
}

/// Supported audio formats
 final  List<AudioFormat> _supportedFormats;
/// Supported audio formats
@override List<AudioFormat> get supportedFormats {
  if (_supportedFormats is EqualUnmodifiableListView) return _supportedFormats;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_supportedFormats);
}

/// Whether noise reduction is supported
@override@JsonKey() final  bool supportsNoiseReduction;
/// Whether echo cancellation is supported
@override@JsonKey() final  bool supportsEchoCancellation;
/// Whether automatic gain control is supported
@override@JsonKey() final  bool supportsAutomaticGainControl;
/// Whether voice activity detection is supported
@override@JsonKey() final  bool supportsVoiceActivityDetection;
/// Maximum supported gain level
@override@JsonKey() final  double maxGainLevel;
/// Minimum supported gain level
@override@JsonKey() final  double minGainLevel;
/// Available buffer sizes
 final  List<int> _availableBufferSizes;
/// Available buffer sizes
@override List<int> get availableBufferSizes {
  if (_availableBufferSizes is EqualUnmodifiableListView) return _availableBufferSizes;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_availableBufferSizes);
}


/// Create a copy of AudioCapabilities
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$AudioCapabilitiesCopyWith<_AudioCapabilities> get copyWith => __$AudioCapabilitiesCopyWithImpl<_AudioCapabilities>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$AudioCapabilitiesToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _AudioCapabilities&&const DeepCollectionEquality().equals(other._supportedSampleRates, _supportedSampleRates)&&const DeepCollectionEquality().equals(other._supportedChannels, _supportedChannels)&&const DeepCollectionEquality().equals(other._supportedFormats, _supportedFormats)&&(identical(other.supportsNoiseReduction, supportsNoiseReduction) || other.supportsNoiseReduction == supportsNoiseReduction)&&(identical(other.supportsEchoCancellation, supportsEchoCancellation) || other.supportsEchoCancellation == supportsEchoCancellation)&&(identical(other.supportsAutomaticGainControl, supportsAutomaticGainControl) || other.supportsAutomaticGainControl == supportsAutomaticGainControl)&&(identical(other.supportsVoiceActivityDetection, supportsVoiceActivityDetection) || other.supportsVoiceActivityDetection == supportsVoiceActivityDetection)&&(identical(other.maxGainLevel, maxGainLevel) || other.maxGainLevel == maxGainLevel)&&(identical(other.minGainLevel, minGainLevel) || other.minGainLevel == minGainLevel)&&const DeepCollectionEquality().equals(other._availableBufferSizes, _availableBufferSizes));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(_supportedSampleRates),const DeepCollectionEquality().hash(_supportedChannels),const DeepCollectionEquality().hash(_supportedFormats),supportsNoiseReduction,supportsEchoCancellation,supportsAutomaticGainControl,supportsVoiceActivityDetection,maxGainLevel,minGainLevel,const DeepCollectionEquality().hash(_availableBufferSizes));

@override
String toString() {
  return 'AudioCapabilities(supportedSampleRates: $supportedSampleRates, supportedChannels: $supportedChannels, supportedFormats: $supportedFormats, supportsNoiseReduction: $supportsNoiseReduction, supportsEchoCancellation: $supportsEchoCancellation, supportsAutomaticGainControl: $supportsAutomaticGainControl, supportsVoiceActivityDetection: $supportsVoiceActivityDetection, maxGainLevel: $maxGainLevel, minGainLevel: $minGainLevel, availableBufferSizes: $availableBufferSizes)';
}


}

/// @nodoc
abstract mixin class _$AudioCapabilitiesCopyWith<$Res> implements $AudioCapabilitiesCopyWith<$Res> {
  factory _$AudioCapabilitiesCopyWith(_AudioCapabilities value, $Res Function(_AudioCapabilities) _then) = __$AudioCapabilitiesCopyWithImpl;
@override @useResult
$Res call({
 List<int> supportedSampleRates, List<int> supportedChannels, List<AudioFormat> supportedFormats, bool supportsNoiseReduction, bool supportsEchoCancellation, bool supportsAutomaticGainControl, bool supportsVoiceActivityDetection, double maxGainLevel, double minGainLevel, List<int> availableBufferSizes
});




}
/// @nodoc
class __$AudioCapabilitiesCopyWithImpl<$Res>
    implements _$AudioCapabilitiesCopyWith<$Res> {
  __$AudioCapabilitiesCopyWithImpl(this._self, this._then);

  final _AudioCapabilities _self;
  final $Res Function(_AudioCapabilities) _then;

/// Create a copy of AudioCapabilities
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? supportedSampleRates = null,Object? supportedChannels = null,Object? supportedFormats = null,Object? supportsNoiseReduction = null,Object? supportsEchoCancellation = null,Object? supportsAutomaticGainControl = null,Object? supportsVoiceActivityDetection = null,Object? maxGainLevel = null,Object? minGainLevel = null,Object? availableBufferSizes = null,}) {
  return _then(_AudioCapabilities(
supportedSampleRates: null == supportedSampleRates ? _self._supportedSampleRates : supportedSampleRates // ignore: cast_nullable_to_non_nullable
as List<int>,supportedChannels: null == supportedChannels ? _self._supportedChannels : supportedChannels // ignore: cast_nullable_to_non_nullable
as List<int>,supportedFormats: null == supportedFormats ? _self._supportedFormats : supportedFormats // ignore: cast_nullable_to_non_nullable
as List<AudioFormat>,supportsNoiseReduction: null == supportsNoiseReduction ? _self.supportsNoiseReduction : supportsNoiseReduction // ignore: cast_nullable_to_non_nullable
as bool,supportsEchoCancellation: null == supportsEchoCancellation ? _self.supportsEchoCancellation : supportsEchoCancellation // ignore: cast_nullable_to_non_nullable
as bool,supportsAutomaticGainControl: null == supportsAutomaticGainControl ? _self.supportsAutomaticGainControl : supportsAutomaticGainControl // ignore: cast_nullable_to_non_nullable
as bool,supportsVoiceActivityDetection: null == supportsVoiceActivityDetection ? _self.supportsVoiceActivityDetection : supportsVoiceActivityDetection // ignore: cast_nullable_to_non_nullable
as bool,maxGainLevel: null == maxGainLevel ? _self.maxGainLevel : maxGainLevel // ignore: cast_nullable_to_non_nullable
as double,minGainLevel: null == minGainLevel ? _self.minGainLevel : minGainLevel // ignore: cast_nullable_to_non_nullable
as double,availableBufferSizes: null == availableBufferSizes ? _self._availableBufferSizes : availableBufferSizes // ignore: cast_nullable_to_non_nullable
as List<int>,
  ));
}


}

// dart format on
