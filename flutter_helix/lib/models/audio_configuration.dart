// ABOUTME: Audio configuration data model for audio processing settings
// ABOUTME: Immutable configuration object using Freezed for type safety

import 'package:freezed_annotation/freezed_annotation.dart';

part 'audio_configuration.freezed.dart';
part 'audio_configuration.g.dart';

/// Audio quality levels
enum AudioQuality {
  low,      // 8kHz, lower quality for bandwidth savings
  medium,   // 16kHz, standard quality for speech
  high,     // 44.1kHz, high quality for music/recording
}

/// Audio format types
enum AudioFormat {
  wav,
  mp3,
  aac,
  flac,
}

/// Audio configuration for recording and processing
@freezed
class AudioConfiguration with _$AudioConfiguration {
  const factory AudioConfiguration({
    /// Sample rate in Hz (e.g., 16000 for 16kHz)
    @Default(16000) int sampleRate,
    
    /// Number of audio channels (1 for mono, 2 for stereo)
    @Default(1) int channels,
    
    /// Bit rate for encoding (in bits per second)
    @Default(64000) int bitRate,
    
    /// Audio quality level
    @Default(AudioQuality.medium) AudioQuality quality,
    
    /// Audio format for recording
    @Default(AudioFormat.wav) AudioFormat format,
    
    /// Enable noise reduction
    @Default(true) bool enableNoiseReduction,
    
    /// Enable echo cancellation
    @Default(true) bool enableEchoCancellation,
    
    /// Enable automatic gain control
    @Default(true) bool enableAutomaticGainControl,
    
    /// Audio gain level (0.0 to 2.0, 1.0 is normal)
    @Default(1.0) double gainLevel,
    
    /// Enable voice activity detection
    @Default(true) bool enableVoiceActivityDetection,
    
    /// Voice activity detection threshold (0.0 to 1.0)
    @Default(0.01) double vadThreshold,
    
    /// Buffer size in frames for audio processing
    @Default(4096) int bufferSize,
    
    /// Selected audio input device ID
    String? selectedDeviceId,
    
    /// Enable real-time audio streaming
    @Default(true) bool enableRealTimeStreaming,
    
    /// Audio chunk duration for processing (in milliseconds)
    @Default(100) int chunkDurationMs,
  }) = _AudioConfiguration;

  factory AudioConfiguration.fromJson(Map<String, dynamic> json) =>
      _$AudioConfigurationFromJson(json);

  /// Create configuration optimized for speech recognition
  factory AudioConfiguration.speechRecognition() {
    return const AudioConfiguration(
      sampleRate: 16000,
      channels: 1,
      quality: AudioQuality.medium,
      format: AudioFormat.wav,
      enableNoiseReduction: true,
      enableVoiceActivityDetection: true,
      vadThreshold: 0.01,
    );
  }

  /// Create configuration optimized for high-quality recording
  factory AudioConfiguration.highQualityRecording() {
    return const AudioConfiguration(
      sampleRate: 44100,
      channels: 2,
      quality: AudioQuality.high,
      format: AudioFormat.flac,
      bitRate: 128000,
      enableNoiseReduction: false,
      enableAutomaticGainControl: false,
    );
  }

  /// Create configuration optimized for low bandwidth
  factory AudioConfiguration.lowBandwidth() {
    return const AudioConfiguration(
      sampleRate: 8000,
      channels: 1,
      quality: AudioQuality.low,
      format: AudioFormat.mp3,
      bitRate: 32000,
      enableNoiseReduction: true,
      vadThreshold: 0.05,
    );
  }
}

/// Audio processing capabilities of the device
@freezed
class AudioCapabilities with _$AudioCapabilities {
  const factory AudioCapabilities({
    /// Supported sample rates
    required List<int> supportedSampleRates,
    
    /// Supported channel counts
    required List<int> supportedChannels,
    
    /// Supported audio formats
    required List<AudioFormat> supportedFormats,
    
    /// Whether noise reduction is supported
    @Default(false) bool supportsNoiseReduction,
    
    /// Whether echo cancellation is supported
    @Default(false) bool supportsEchoCancellation,
    
    /// Whether automatic gain control is supported
    @Default(false) bool supportsAutomaticGainControl,
    
    /// Whether voice activity detection is supported
    @Default(false) bool supportsVoiceActivityDetection,
    
    /// Maximum supported gain level
    @Default(2.0) double maxGainLevel,
    
    /// Minimum supported gain level
    @Default(0.0) double minGainLevel,
    
    /// Available buffer sizes
    required List<int> availableBufferSizes,
  }) = _AudioCapabilities;

  factory AudioCapabilities.fromJson(Map<String, dynamic> json) =>
      _$AudioCapabilitiesFromJson(json);
}