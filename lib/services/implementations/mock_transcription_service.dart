import 'dart:async';
import '../../models/audio_chunk.dart';
import '../../models/transcript_segment.dart';
import '../interfaces/i_transcription_service.dart';

/// Mock transcription service for testing
/// Simulates speech recognition without requiring native platform
class MockTranscriptionService implements ITranscriptionService {
  final _transcriptController =
      StreamController<TranscriptSegment>.broadcast();

  bool _isTranscribing = false;
  final List<AudioChunk> _receivedAudioChunks = [];

  // Test configuration
  Duration processingDelay = const Duration(milliseconds: 100);
  String? forcedTranscriptResult;

  @override
  Stream<TranscriptSegment> get transcriptStream =>
      _transcriptController.stream;

  @override
  bool get isTranscribing => _isTranscribing;

  /// Test helper: access received audio chunks
  List<AudioChunk> get receivedAudioChunks => List.unmodifiable(_receivedAudioChunks);

  @override
  Future<void> startTranscription() async {
    _isTranscribing = true;
    await Future.delayed(const Duration(milliseconds: 50));
  }

  @override
  Future<void> stopTranscription() async {
    _isTranscribing = false;
    await Future.delayed(const Duration(milliseconds: 50));
  }

  @override
  Future<void> processAudio(AudioChunk chunk) async {
    if (!_isTranscribing) return;

    _receivedAudioChunks.add(chunk);

    await Future.delayed(processingDelay);

    // Simulate transcription result
    if (forcedTranscriptResult != null) {
      _transcriptController.add(
        TranscriptSegment.fromSpeechRecognition(
          text: forcedTranscriptResult!,
          isFinal: true,
        ),
      );
    }
  }

  @override
  void clear() {
    _receivedAudioChunks.clear();
  }

  @override
  void dispose() {
    _transcriptController.close();
  }

  // Test helper methods

  /// Simulate a transcription result
  void simulateTranscript(
    String text, {
    bool isFinal = true,
    double confidence = 0.95,
  }) {
    _transcriptController.add(
      TranscriptSegment(
        text: text,
        timestamp: DateTime.now(),
        confidence: confidence,
        isFinal: isFinal,
      ),
    );
  }

  /// Simulate partial (non-final) transcript
  void simulatePartialTranscript(String text) {
    simulateTranscript(text, isFinal: false, confidence: 0.7);
  }

  /// Simulate transcription error
  void simulateError() {
    _transcriptController.addError(Exception('Transcription failed'));
  }
}
