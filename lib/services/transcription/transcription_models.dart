/// Transcription mode selection (US 3.1)
enum TranscriptionMode {
  /// Use native iOS Speech Recognition (on-device)
  native,

  /// Use OpenAI Whisper API (cloud)
  whisper,

  /// Automatically choose based on network connectivity
  auto,
}

/// A segment of transcribed text with metadata
class TranscriptSegment {
  final String text;
  final double confidence; // 0.0 to 1.0
  final DateTime timestamp;
  final bool isFinal; // true if this is a finalized segment
  final TranscriptionMode source; // which mode produced this segment

  const TranscriptSegment({
    required this.text,
    required this.confidence,
    required this.timestamp,
    this.isFinal = false,
    required this.source,
  });

  /// Create a copy with modified fields
  TranscriptSegment copyWith({
    String? text,
    double? confidence,
    DateTime? timestamp,
    bool? isFinal,
    TranscriptionMode? source,
  }) {
    return TranscriptSegment(
      text: text ?? this.text,
      confidence: confidence ?? this.confidence,
      timestamp: timestamp ?? this.timestamp,
      isFinal: isFinal ?? this.isFinal,
      source: source ?? this.source,
    );
  }

  @override
  String toString() {
    return 'TranscriptSegment(text: $text, confidence: $confidence, '
        'isFinal: $isFinal, source: $source)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is TranscriptSegment &&
        other.text == text &&
        other.confidence == confidence &&
        other.timestamp == timestamp &&
        other.isFinal == isFinal &&
        other.source == source;
  }

  @override
  int get hashCode {
    return text.hashCode ^
        confidence.hashCode ^
        timestamp.hashCode ^
        isFinal.hashCode ^
        source.hashCode;
  }
}

/// Transcription error types
enum TranscriptionErrorType {
  notAuthorized,
  notAvailable,
  networkError,
  audioProcessingError,
  apiError,
  unknown,
}

/// Transcription error with details
class TranscriptionError implements Exception {
  final TranscriptionErrorType type;
  final String message;
  final dynamic originalError;

  const TranscriptionError({
    required this.type,
    required this.message,
    this.originalError,
  });

  @override
  String toString() {
    return 'TranscriptionError($type): $message';
  }
}

/// Transcription statistics
class TranscriptionStats {
  final int segmentCount;
  final int totalCharacters;
  final Duration totalDuration;
  final double averageConfidence;
  final TranscriptionMode activeMode;

  const TranscriptionStats({
    required this.segmentCount,
    required this.totalCharacters,
    required this.totalDuration,
    required this.averageConfidence,
    required this.activeMode,
  });

  Map<String, dynamic> toJson() {
    return {
      'segmentCount': segmentCount,
      'totalCharacters': totalCharacters,
      'totalDurationMs': totalDuration.inMilliseconds,
      'averageConfidence': averageConfidence,
      'activeMode': activeMode.toString(),
    };
  }
}
