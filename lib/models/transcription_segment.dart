// ABOUTME: Transcription segment models
// ABOUTME: Models for speech-to-text transcription results

/// Transcription segment
class TranscriptionSegment {
  final String id;
  final String text;
  final int startTimeMs;
  final int endTimeMs;
  final double confidence;
  final String? speakerId;
  final bool isFinal;

  TranscriptionSegment({
    required this.id,
    required this.text,
    required this.startTimeMs,
    required this.endTimeMs,
    required this.confidence,
    this.speakerId,
    this.isFinal = true,
  });

  Duration get duration =>
      Duration(milliseconds: endTimeMs - startTimeMs);

  bool get isLongEnough => duration.inMilliseconds > 500;
}

/// Transcription result
class TranscriptionResult {
  final String id;
  final String text;
  final List<TranscriptionSegment> segments;
  final double confidence;
  final DateTime timestamp;
  final String? language;

  TranscriptionResult({
    required this.id,
    required this.text,
    this.segments = const [],
    this.confidence = 1.0,
    required this.timestamp,
    this.language,
  });

  bool get isEmpty => text.trim().isEmpty;
  bool get isNotEmpty => !isEmpty;
}
