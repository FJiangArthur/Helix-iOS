import 'dart:async';
import 'package:flutter/services.dart';
import '../../models/audio_chunk.dart';
import '../../models/transcript_segment.dart';
import '../interfaces/i_transcription_service.dart';

/// Production implementation of ITranscriptionService using iOS SpeechRecognizer
/// Wraps the native iOS speech recognition via EventChannel
class TranscriptionServiceImpl implements ITranscriptionService {
  final _transcriptController =
      StreamController<TranscriptSegment>.broadcast();

  bool _isTranscribing = false;
  StreamSubscription? _nativeSubscription;

  static const String _eventChannelName = "eventSpeechRecognize";
  final EventChannel _eventChannel =
      const EventChannel(_eventChannelName);

  @override
  Stream<TranscriptSegment> get transcriptStream =>
      _transcriptController.stream;

  @override
  bool get isTranscribing => _isTranscribing;

  @override
  Future<void> startTranscription() async {
    if (_isTranscribing) return;

    _isTranscribing = true;

    // Listen to iOS SpeechStreamRecognizer via EventChannel
    _nativeSubscription = _eventChannel
        .receiveBroadcastStream(_eventChannelName)
        .listen(
      (event) {
        if (event is Map) {
          _handleNativeTranscript(event);
        }
      },
      onError: (error) {
        print('Transcription error: $error');
        _transcriptController.addError(error);
      },
    );
  }

  @override
  Future<void> stopTranscription() async {
    if (!_isTranscribing) return;

    _isTranscribing = false;
    await _nativeSubscription?.cancel();
    _nativeSubscription = null;
  }

  @override
  Future<void> processAudio(AudioChunk chunk) async {
    // For iOS speech recognition, audio is processed directly by the native layer
    // This method is more relevant for services that process recorded audio
    // For now, we rely on startTranscription() which uses the microphone directly

    // If we need to process recorded audio files, we would:
    // 1. Write audio chunk to temp file
    // 2. Use SFSpeechRecognizer's recognitionTask(with: SFSpeechURLRecognitionRequest)
    // 3. Send results back via method channel

    // For live transcription, this is a no-op
  }

  @override
  void clear() {
    // Native speech recognizer handles its own state
    // Nothing to clear here
  }

  @override
  void dispose() {
    stopTranscription();
    _transcriptController.close();
  }

  /// Handle transcript data from native iOS SpeechStreamRecognizer
  void _handleNativeTranscript(Map event) {
    try {
      // Native iOS sends: {"script": "transcribed text", "isFinal": bool}
      final text = event['script'] as String?;
      final isFinal = event['isFinal'] as bool? ?? false;

      if (text == null || text.isEmpty) return;

      final segment = TranscriptSegment.fromSpeechRecognition(
        text: text,
        isFinal: isFinal,
      );

      _transcriptController.add(segment);
    } catch (e) {
      print('Error handling native transcript: $e');
    }
  }
}
