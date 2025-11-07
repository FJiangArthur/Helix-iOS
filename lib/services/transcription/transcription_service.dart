import 'dart:async';
import 'dart:typed_data';
import 'transcription_models.dart';

/// Base interface for transcription services (US 3.1)
/// Implementations: NativeTranscriptionService, WhisperTranscriptionService
abstract class TranscriptionService {
  /// Transcription mode this service provides
  TranscriptionMode get mode;

  /// Whether the service is currently available
  bool get isAvailable;

  /// Whether transcription is currently running
  bool get isTranscribing;

  /// Stream of transcription segments as they are recognized
  Stream<TranscriptSegment> get transcriptStream;

  /// Stream of errors during transcription
  Stream<TranscriptionError> get errorStream;

  /// Initialize the transcription service
  /// Checks permissions and availability
  Future<void> initialize();

  /// Start transcribing audio
  /// [languageCode] - Optional language code (e.g., "en-US", "zh-CN")
  Future<void> startTranscription({String? languageCode});

  /// Stop transcribing and finalize
  Future<void> stopTranscription();

  /// Append PCM audio data for transcription
  /// [pcmData] - Raw PCM audio bytes (16kHz, 16-bit, mono)
  void appendAudioData(Uint8List pcmData);

  /// Get current transcription statistics
  TranscriptionStats getStats();

  /// Clean up resources
  void dispose();
}
