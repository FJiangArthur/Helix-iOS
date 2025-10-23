import 'package:freezed_annotation/freezed_annotation.dart';

part 'transcript_segment.freezed.dart';
part 'transcript_segment.g.dart';

/// A single segment of transcribed speech
@freezed
class TranscriptSegment with _$TranscriptSegment {
  const factory TranscriptSegment({
    required String text,
    required DateTime timestamp,
    @Default(1.0) double confidence,
    @Default(false) bool isFinal,
    int? speakerId,
  }) = _TranscriptSegment;

  factory TranscriptSegment.fromJson(Map<String, dynamic> json) =>
      _$TranscriptSegmentFromJson(json);

  /// Create a segment from iOS speech recognition result
  factory TranscriptSegment.fromSpeechRecognition({
    required String text,
    bool isFinal = false,
  }) =>
      TranscriptSegment(
        text: text,
        timestamp: DateTime.now(),
        isFinal: isFinal,
        confidence: 0.95,
      );
}
