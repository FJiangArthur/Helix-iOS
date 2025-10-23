import 'dart:async';
import 'dart:typed_data';
import '../../models/transcript_segment.dart';
import '../../models/audio_chunk.dart';

/// Abstract interface for speech-to-text transcription
abstract class ITranscriptionService {
  /// Stream of transcribed text segments
  Stream<TranscriptSegment> get transcriptStream;

  /// Whether transcription is currently active
  bool get isTranscribing;

  /// Start transcription
  Future<void> startTranscription();

  /// Stop transcription
  Future<void> stopTranscription();

  /// Process audio chunk for transcription
  /// Used when feeding audio from recording rather than live microphone
  Future<void> processAudio(AudioChunk chunk);

  /// Clear accumulated transcription
  void clear();

  /// Dispose resources
  void dispose();
}
