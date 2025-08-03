// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'audio_configuration.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$AudioConfigurationImpl _$$AudioConfigurationImplFromJson(
  Map<String, dynamic> json,
) => _$AudioConfigurationImpl(
  sampleRate: (json['sampleRate'] as num?)?.toInt() ?? 16000,
  channels: (json['channels'] as num?)?.toInt() ?? 1,
  bitRate: (json['bitRate'] as num?)?.toInt() ?? 64000,
  quality:
      $enumDecodeNullable(_$AudioQualityEnumMap, json['quality']) ??
      AudioQuality.medium,
  format:
      $enumDecodeNullable(_$AudioFormatEnumMap, json['format']) ??
      AudioFormat.wav,
  enableNoiseReduction: json['enableNoiseReduction'] as bool? ?? true,
  enableEchoCancellation: json['enableEchoCancellation'] as bool? ?? true,
  enableAutomaticGainControl:
      json['enableAutomaticGainControl'] as bool? ?? true,
  gainLevel: (json['gainLevel'] as num?)?.toDouble() ?? 1.0,
  enableVoiceActivityDetection:
      json['enableVoiceActivityDetection'] as bool? ?? true,
  vadThreshold: (json['vadThreshold'] as num?)?.toDouble() ?? 0.01,
  bufferSize: (json['bufferSize'] as num?)?.toInt() ?? 4096,
  selectedDeviceId: json['selectedDeviceId'] as String?,
  enableRealTimeStreaming: json['enableRealTimeStreaming'] as bool? ?? true,
  chunkDurationMs: (json['chunkDurationMs'] as num?)?.toInt() ?? 100,
);

Map<String, dynamic> _$$AudioConfigurationImplToJson(
  _$AudioConfigurationImpl instance,
) => <String, dynamic>{
  'sampleRate': instance.sampleRate,
  'channels': instance.channels,
  'bitRate': instance.bitRate,
  'quality': _$AudioQualityEnumMap[instance.quality]!,
  'format': _$AudioFormatEnumMap[instance.format]!,
  'enableNoiseReduction': instance.enableNoiseReduction,
  'enableEchoCancellation': instance.enableEchoCancellation,
  'enableAutomaticGainControl': instance.enableAutomaticGainControl,
  'gainLevel': instance.gainLevel,
  'enableVoiceActivityDetection': instance.enableVoiceActivityDetection,
  'vadThreshold': instance.vadThreshold,
  'bufferSize': instance.bufferSize,
  'selectedDeviceId': instance.selectedDeviceId,
  'enableRealTimeStreaming': instance.enableRealTimeStreaming,
  'chunkDurationMs': instance.chunkDurationMs,
};

const _$AudioQualityEnumMap = {
  AudioQuality.low: 'low',
  AudioQuality.medium: 'medium',
  AudioQuality.high: 'high',
};

const _$AudioFormatEnumMap = {
  AudioFormat.wav: 'wav',
  AudioFormat.mp3: 'mp3',
  AudioFormat.aac: 'aac',
  AudioFormat.flac: 'flac',
};

_$AudioCapabilitiesImpl _$$AudioCapabilitiesImplFromJson(
  Map<String, dynamic> json,
) => _$AudioCapabilitiesImpl(
  supportedSampleRates:
      (json['supportedSampleRates'] as List<dynamic>)
          .map((e) => (e as num).toInt())
          .toList(),
  supportedChannels:
      (json['supportedChannels'] as List<dynamic>)
          .map((e) => (e as num).toInt())
          .toList(),
  supportedFormats:
      (json['supportedFormats'] as List<dynamic>)
          .map((e) => $enumDecode(_$AudioFormatEnumMap, e))
          .toList(),
  supportsNoiseReduction: json['supportsNoiseReduction'] as bool? ?? false,
  supportsEchoCancellation: json['supportsEchoCancellation'] as bool? ?? false,
  supportsAutomaticGainControl:
      json['supportsAutomaticGainControl'] as bool? ?? false,
  supportsVoiceActivityDetection:
      json['supportsVoiceActivityDetection'] as bool? ?? false,
  maxGainLevel: (json['maxGainLevel'] as num?)?.toDouble() ?? 2.0,
  minGainLevel: (json['minGainLevel'] as num?)?.toDouble() ?? 0.0,
  availableBufferSizes:
      (json['availableBufferSizes'] as List<dynamic>)
          .map((e) => (e as num).toInt())
          .toList(),
);

Map<String, dynamic> _$$AudioCapabilitiesImplToJson(
  _$AudioCapabilitiesImpl instance,
) => <String, dynamic>{
  'supportedSampleRates': instance.supportedSampleRates,
  'supportedChannels': instance.supportedChannels,
  'supportedFormats':
      instance.supportedFormats.map((e) => _$AudioFormatEnumMap[e]!).toList(),
  'supportsNoiseReduction': instance.supportsNoiseReduction,
  'supportsEchoCancellation': instance.supportsEchoCancellation,
  'supportsAutomaticGainControl': instance.supportsAutomaticGainControl,
  'supportsVoiceActivityDetection': instance.supportsVoiceActivityDetection,
  'maxGainLevel': instance.maxGainLevel,
  'minGainLevel': instance.minGainLevel,
  'availableBufferSizes': instance.availableBufferSizes,
};
