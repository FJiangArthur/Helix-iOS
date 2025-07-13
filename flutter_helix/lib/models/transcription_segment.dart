// ABOUTME: Transcription segment data model for speech-to-text results
// ABOUTME: Represents individual pieces of transcribed speech with timing and metadata

import 'package:freezed_annotation/freezed_annotation.dart';

part 'transcription_segment.freezed.dart';
part 'transcription_segment.g.dart';

/// Transcription segment representing a piece of spoken text
@freezed
class TranscriptionSegment with _$TranscriptionSegment {
  const factory TranscriptionSegment({
    /// Unique identifier for this segment
    required String id,
    
    /// Transcribed text content
    required String text,
    
    /// Start time of the segment (in milliseconds from recording start)
    required int startTimeMs,
    
    /// End time of the segment (in milliseconds from recording start)
    required int endTimeMs,
    
    /// Confidence score for the transcription (0.0 to 1.0)
    required double confidence,
    
    /// Speaker information (if available)
    String? speakerId,
    
    /// Speaker name (if known)
    String? speakerName,
    
    /// Language code for the transcribed text
    @Default('en-US') String language,
    
    /// Whether this is a final transcription or interim result
    @Default(true) bool isFinal,
    
    /// Transcription backend used ('local', 'whisper', etc.)
    String? backend,
    
    /// Processing time in milliseconds
    int? processingTimeMs,
    
    /// Additional metadata
    @Default({}) Map<String, dynamic> metadata,
    
    /// Timestamp when this segment was created
    required DateTime timestamp,
  }) = _TranscriptionSegment;

  factory TranscriptionSegment.fromJson(Map<String, dynamic> json) =>
      _$TranscriptionSegmentFromJson(json);

  /// Create a new segment with updated text (for interim results)
  const TranscriptionSegment._();

  /// Duration of this segment in milliseconds
  int get durationMs => endTimeMs - startTimeMs;

  /// Duration of this segment
  Duration get duration => Duration(milliseconds: durationMs);

  /// Whether this segment has speaker information
  bool get hasSpeakerInfo => speakerId != null || speakerName != null;

  /// Display name for the speaker
  String get speakerDisplayName {
    if (speakerName != null) return speakerName!;
    if (speakerId != null) return 'Speaker $speakerId';
    return 'Unknown Speaker';
  }

  /// Whether this is a high-confidence transcription
  bool get isHighConfidence => confidence >= 0.8;

  /// Whether this is a low-confidence transcription
  bool get isLowConfidence => confidence < 0.5;

  /// Formatted time range string
  String get timeRangeString {
    final start = Duration(milliseconds: startTimeMs);
    final end = Duration(milliseconds: endTimeMs);
    return '${_formatDuration(start)} - ${_formatDuration(end)}';
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    final milliseconds = duration.inMilliseconds % 1000;
    return '${minutes.toString().padLeft(2, '0')}:'
           '${seconds.toString().padLeft(2, '0')}.'
           '${(milliseconds ~/ 10).toString().padLeft(2, '0')}';
  }
}

/// Collection of transcription segments for a conversation
@freezed
class TranscriptionResult with _$TranscriptionResult {
  const factory TranscriptionResult({
    /// Unique identifier for this transcription result
    required String id,
    
    /// List of transcription segments
    required List<TranscriptionSegment> segments,
    
    /// Overall confidence score for the entire transcription
    required double overallConfidence,
    
    /// Total duration of the transcription
    required Duration totalDuration,
    
    /// Language code for the transcription
    @Default('en-US') String language,
    
    /// Transcription backend used
    String? backend,
    
    /// Total processing time
    Duration? processingTime,
    
    /// Number of speakers detected
    @Default(1) int speakerCount,
    
    /// Whether speaker diarization was performed
    @Default(false) bool hasSpeakerDiarization,
    
    /// Additional metadata for the entire transcription
    @Default({}) Map<String, dynamic> metadata,
    
    /// Timestamp when this result was created
    required DateTime timestamp,
  }) = _TranscriptionResult;

  factory TranscriptionResult.fromJson(Map<String, dynamic> json) =>
      _$TranscriptionResultFromJson(json);

  const TranscriptionResult._();

  /// Get the full transcribed text
  String get fullText => segments.map((s) => s.text).join(' ');

  /// Get segments for a specific speaker
  List<TranscriptionSegment> getSegmentsForSpeaker(String speakerId) {
    return segments.where((s) => s.speakerId == speakerId).toList();
  }

  /// Get all unique speaker IDs
  List<String> get speakerIds {
    return segments
        .where((s) => s.speakerId != null)
        .map((s) => s.speakerId!)
        .toSet()
        .toList();
  }

  /// Get segments within a time range
  List<TranscriptionSegment> getSegmentsInRange(int startMs, int endMs) {
    return segments
        .where((s) => s.startTimeMs >= startMs && s.endTimeMs <= endMs)
        .toList();
  }

  /// Get high-confidence segments only
  List<TranscriptionSegment> get highConfidenceSegments {
    return segments.where((s) => s.isHighConfidence).toList();
  }

  /// Get low-confidence segments that may need review
  List<TranscriptionSegment> get lowConfidenceSegments {
    return segments.where((s) => s.isLowConfidence).toList();
  }

  /// Calculate words per minute
  double get wordsPerMinute {
    final wordCount = fullText.split(' ').length;
    final minutes = totalDuration.inMilliseconds / 60000.0;
    return minutes > 0 ? wordCount / minutes : 0.0;
  }
}