// ABOUTME: Audio service interface for audio capture, processing, and recording
// ABOUTME: Abstracts platform-specific audio operations for cross-platform compatibility

import 'dart:async';
import 'dart:typed_data';

import '../models/audio_configuration.dart';

/// Service interface for audio capture, processing, and recording management
abstract class AudioService {
  /// Current audio configuration
  AudioConfiguration get configuration;
  
  /// Whether audio recording is currently active
  bool get isRecording;
  
  /// Whether audio permission has been granted
  bool get hasPermission;
  
  /// Stream of real-time audio data for processing
  Stream<Uint8List> get audioStream;
  
  /// Stream of audio level updates for UI visualization
  Stream<double> get audioLevelStream;
  
  /// Stream of voice activity detection updates
  Stream<bool> get voiceActivityStream;

  /// Stream of recording duration updates (alias for backward compatibility)
  Stream<Duration> get durationStream;

  /// Initialize the audio service with configuration
  Future<void> initialize(AudioConfiguration config);

  /// Get current recording duration
  Future<Duration?> getRecordingDuration();

  /// Request audio permission from the user
  Future<bool> requestPermission();

  /// Start audio recording and streaming
  Future<void> startRecording();

  /// Stop audio recording
  Future<void> stopRecording();

  /// Pause audio recording (if supported)
  Future<void> pauseRecording();

  /// Resume audio recording from pause
  Future<void> resumeRecording();

  /// Start a new conversation recording session
  /// Returns the file path where the recording will be saved
  Future<String> startConversationRecording(String conversationId);

  /// Stop conversation recording and finalize the file
  Future<void> stopConversationRecording();

  /// Get available audio input devices
  Future<List<AudioInputDevice>> getInputDevices();

  /// Select a specific audio input device
  Future<void> selectInputDevice(String deviceId);

  /// Configure audio processing parameters
  Future<void> configureAudioProcessing({
    bool enableNoiseReduction = true,
    bool enableEchoCancellation = true,
    double gainLevel = 1.0,
  });

  /// Enable or disable voice activity detection
  Future<void> setVoiceActivityDetection(bool enabled);

  /// Set audio quality level
  Future<void> setAudioQuality(AudioQuality quality);

  /// Test audio recording functionality
  Future<bool> testAudioRecording();

  /// Get the current recording file path (if recording)
  String? get currentRecordingPath;

  /// Clean up resources and stop all audio operations
  Future<void> dispose();
}

/// Represents an audio input device
class AudioInputDevice {
  final String id;
  final String name;
  final String type; // 'built-in', 'bluetooth', 'external'
  final bool isDefault;

  const AudioInputDevice({
    required this.id,
    required this.name,
    required this.type,
    this.isDefault = false,
  });

  @override
  String toString() => 'AudioInputDevice(id: $id, name: $name, type: $type, isDefault: $isDefault)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AudioInputDevice &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}