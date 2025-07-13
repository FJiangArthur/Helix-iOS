// ABOUTME: Transcription service interface for speech-to-text conversion
// ABOUTME: Supports both local and remote transcription backends with quality switching

import 'dart:async';
import 'dart:typed_data';

import '../models/transcription_segment.dart';
import '../core/utils/exceptions.dart';

/// Backend type for transcription processing
enum TranscriptionBackend {
  local,    // On-device speech recognition
  whisper,  // OpenAI Whisper API
  hybrid,   // Automatic selection based on quality/connectivity
}

/// Real-time transcription state
enum TranscriptionState {
  idle,
  listening,
  processing,
  error,
}

/// Service interface for speech-to-text transcription
abstract class TranscriptionService {
  /// Current transcription backend being used
  TranscriptionBackend get currentBackend;
  
  /// Current transcription state
  TranscriptionState get state;
  
  /// Whether the service is currently active
  bool get isActive;
  
  /// Stream of real-time transcription segments
  Stream<TranscriptionSegment> get transcriptionStream;
  
  /// Stream of transcription state changes
  Stream<TranscriptionState> get stateStream;
  
  /// Stream of backend changes (for quality switching)
  Stream<TranscriptionBackend> get backendStream;

  /// Initialize the transcription service
  Future<void> initialize();

  /// Check if speech recognition is available on this device
  Future<bool> isAvailable();

  /// Request speech recognition permission
  Future<bool> requestPermission();

  /// Start real-time transcription
  Future<void> startTranscription({
    TranscriptionBackend? preferredBackend,
    String? language,
    bool enablePunctuation = true,
    bool enableCapitalization = true,
  });

  /// Stop real-time transcription
  Future<void> stopTranscription();

  /// Process audio data and return transcription
  Future<TranscriptionSegment> transcribeAudio(
    Uint8List audioData, {
    TranscriptionBackend? backend,
    String? language,
  });

  /// Process audio file and return transcription
  Future<List<TranscriptionSegment>> transcribeFile(
    String filePath, {
    TranscriptionBackend? backend,
    String? language,
  });

  /// Set preferred transcription backend
  Future<void> setPreferredBackend(TranscriptionBackend backend);

  /// Configure language settings
  Future<void> setLanguage(String languageCode);

  /// Get available languages for transcription
  Future<List<String>> getAvailableLanguages();

  /// Enable or disable automatic backend switching
  Future<void> setAutomaticBackendSwitching(bool enabled);

  /// Configure transcription quality settings
  Future<void> configureQuality({
    bool enablePunctuation = true,
    bool enableCapitalization = true,
    bool enableSpeakerDiarization = false,
    double confidenceThreshold = 0.5,
  });

  /// Get transcription confidence for the last result
  double getLastConfidence();

  /// Clean up resources
  Future<void> dispose();
}

/// Speaker diarization result
class SpeakerInfo {
  final String speakerId;
  final String? name;
  final double confidence;

  const SpeakerInfo({
    required this.speakerId,
    this.name,
    required this.confidence,
  });

  @override
  String toString() => 'SpeakerInfo(id: $speakerId, name: $name, confidence: $confidence)';
}