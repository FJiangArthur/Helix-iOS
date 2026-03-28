import 'dart:async';

/// Simulates speech transcription events as if coming from the native platform
/// channel `eventSpeechRecognize`.
///
/// Used with [ConversationListeningSession.test()] which accepts a
/// `Stream<dynamic>` for speech events.
class SpeechEventEmitter {
  SpeechEventEmitter({this.backend = SpeechBackendProfile.apple});

  final SpeechBackendProfile backend;
  final _controller = StreamController<dynamic>.broadcast();

  Stream<dynamic> get stream => _controller.stream;
  bool get isClosed => _controller.isClosed;

  /// Emit a partial (non-final) transcription update.
  void emitPartial(
    String text, {
    String? speaker,
    int? timestampMs,
    String? segmentId,
  }) {
    _controller.add({
      'script': text,
      'isFinal': false,
      if (speaker != null) 'speaker': speaker,
      if (timestampMs != null) 'timestampMs': timestampMs,
      if (segmentId != null) 'segmentId': segmentId,
    });
  }

  /// Emit a final transcription segment.
  void emitFinal(
    String text, {
    String? speaker,
    int? timestampMs,
    String? segmentId,
  }) {
    _controller.add({
      'script': text,
      'isFinal': true,
      if (speaker != null) 'speaker': speaker,
      if (timestampMs != null) 'timestampMs': timestampMs,
      if (segmentId != null) 'segmentId': segmentId,
    });
  }

  /// Emit a transcription error.
  void emitError(String errorMessage) {
    _controller.add({
      'error': errorMessage,
    });
  }

  /// Emit a realtime AI response (for OpenAI Realtime backend).
  void emitRealtimeResponse(String text) {
    _controller.add({
      'script': '',
      'isFinal': true,
      'aiResponse': text,
    });
  }

  /// Replay pre-transcribed text as a realistic sequence of partial updates
  /// followed by a final event.
  ///
  /// Words are emitted incrementally to simulate live speech recognition.
  Future<void> feedTranscript(
    String text, {
    Duration partialInterval = const Duration(milliseconds: 50),
    String? speaker,
    String? segmentId,
  }) async {
    final words = text.split(RegExp(r'\s+'));
    final buffer = StringBuffer();
    final baseTimestamp = DateTime.now().millisecondsSinceEpoch;

    for (var i = 0; i < words.length; i++) {
      if (i > 0) buffer.write(' ');
      buffer.write(words[i]);

      final isLast = i == words.length - 1;
      final ts = baseTimestamp + (i * partialInterval.inMilliseconds);

      if (!isLast) {
        emitPartial(
          buffer.toString(),
          speaker: speaker,
          timestampMs: ts,
          segmentId: segmentId,
        );
      } else {
        emitFinal(
          buffer.toString(),
          speaker: speaker,
          timestampMs: ts,
          segmentId: segmentId,
        );
      }

      if (partialInterval > Duration.zero && !isLast) {
        await Future<void>.delayed(partialInterval);
      }
    }
  }

  /// Feed multiple transcript segments with pauses between them.
  Future<void> feedConversation(
    List<({String text, String? speaker, Duration? pause})> segments, {
    Duration partialInterval = const Duration(milliseconds: 20),
  }) async {
    for (var i = 0; i < segments.length; i++) {
      final seg = segments[i];
      await feedTranscript(
        seg.text,
        partialInterval: partialInterval,
        speaker: seg.speaker,
        segmentId: 'seg_$i',
      );
      if (seg.pause != null && seg.pause! > Duration.zero) {
        await Future<void>.delayed(seg.pause!);
      }
    }
  }

  void close() => _controller.close();
}

/// Timing profiles matching different transcription backends.
enum SpeechBackendProfile {
  /// Apple Cloud Speech: fast partial updates (~100ms), short final delay.
  apple,

  /// OpenAI Whisper Batch: no partials, 5-second chunk finals.
  whisper,

  /// OpenAI Realtime: streaming with aiResponse fields.
  realtime,
}
