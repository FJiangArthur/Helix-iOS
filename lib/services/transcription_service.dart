// ABOUTME: Transcription service interface for speech-to-text conversion
// ABOUTME: Supports both local and remote transcription backends with quality switching

import 'dart:async';

import '../models/transcription_segment.dart';

/// Backend type for transcription processing
enum TranscriptionBackend {
  device,   // On-device speech recognition
  whisper,  // OpenAI Whisper API
  hybrid,   // Automatic selection based on quality/connectivity
}

/// Transcription quality settings
enum TranscriptionQuality {
  low,      // Fast, lower accuracy
  standard, // Balanced speed and accuracy
  high,     // High accuracy, slower processing
}

/// Real-time transcription state
enum TranscriptionState {
  idle,
  listening,
  processing,
  error,
}

/// Transcription error types
enum TranscriptionErrorType {
  initializationFailed,
  permissionDenied,
  serviceNotReady,
  networkError,
  audioError,
  unsupportedLanguage,
  unknown,
}

/// Custom exception for transcription errors with specific error types
class TranscriptionServiceException implements Exception {
  final String message;
  final TranscriptionErrorType type;
  final dynamic originalError;

  const TranscriptionServiceException(
    this.message,
    this.type, {
    this.originalError,
  });

  @override
  String toString() => 'TranscriptionServiceException: $message (type: $type)';
}

/// Service interface for speech-to-text transcription
abstract class TranscriptionService {
  /// Whether the service is initialized
  bool get isInitialized;
  
  /// Whether currently transcribing
  bool get isTranscribing;
  
  /// Whether microphone permissions are granted
  bool get hasPermissions;
  
  /// Whether speech recognition is available
  bool get isAvailable;
  
  /// Current language code
  String get currentLanguage;
  
  /// Current transcription backend
  TranscriptionBackend get currentBackend;
  
  /// Current quality setting
  TranscriptionQuality get currentQuality;
  
  /// Current VAD sensitivity (0.0 to 1.0)
  double get vadSensitivity;
  
  /// Stream of real-time transcription segments
  Stream<TranscriptionSegment> get transcriptionStream;
  
  /// Stream of confidence scores
  Stream<double> get confidenceStream;

  /// Initialize the transcription service
  Future<void> initialize();

  /// Request microphone permissions
  Future<bool> requestPermissions();

  /// Start real-time transcription
  Future<void> startTranscription({
    bool enableCapitalization = true,
    bool enablePunctuation = true,
    String? language,
    TranscriptionBackend? preferredBackend,
  });

  /// Stop real-time transcription
  Future<void> stopTranscription();

  /// Pause transcription (can be resumed)
  Future<void> pauseTranscription();

  /// Resume paused transcription
  Future<void> resumeTranscription();

  /// Set transcription language
  Future<void> setLanguage(String languageCode);

  /// Configure transcription quality
  Future<void> configureQuality(TranscriptionQuality quality);

  /// Configure backend
  Future<void> configureBackend(TranscriptionBackend backend);

  /// Get available languages
  Future<List<String>> getAvailableLanguages();

  /// Get last confidence score
  double getLastConfidence();

  /// Transcribe audio file
  Future<TranscriptionSegment> transcribeAudio(String audioPath);

  /// Calibrate voice activity detection
  Future<void> calibrateVoiceActivity();

  /// Set VAD sensitivity
  Future<void> setVADSensitivity(double sensitivity);

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