import 'package:freezed_annotation/freezed_annotation.dart';
import 'transcript_segment.dart';

part 'conversation_session.freezed.dart';
part 'conversation_session.g.dart';

/// Session status lifecycle
enum SessionStatus {
  created,
  recording,
  transcribing,
  completed,
  failed,
}

/// Represents a complete conversation session with recording and transcription
@freezed
class ConversationSession with _$ConversationSession {
  const factory ConversationSession({
    required String id,
    required DateTime startTime,
    DateTime? endTime,
    @Default([]) List<TranscriptSegment> segments,
    String? audioFilePath,
    @Default(SessionStatus.created) SessionStatus status,
    String? errorMessage,
    @Default(0) int durationSeconds,
  }) = _ConversationSession;

  factory ConversationSession.fromJson(Map<String, dynamic> json) =>
      _$ConversationSessionFromJson(json);

  /// Create a new session
  factory ConversationSession.create() => ConversationSession(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        startTime: DateTime.now(),
        status: SessionStatus.created,
      );
}

/// Extension methods for ConversationSession
extension ConversationSessionX on ConversationSession {
  /// Get full transcript text
  String get fullTranscript =>
      segments.map((s) => s.text).join(' ').trim();

  /// Check if session is active
  bool get isActive =>
      status == SessionStatus.recording || status == SessionStatus.transcribing;

  /// Get duration
  Duration get duration {
    if (endTime != null) {
      return endTime!.difference(startTime);
    }
    if (isActive) {
      return DateTime.now().difference(startTime);
    }
    return Duration(seconds: durationSeconds);
  }
}
