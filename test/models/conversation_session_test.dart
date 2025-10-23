import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_helix/models/conversation_session.dart';
import 'package:flutter_helix/models/transcript_segment.dart';

void main() {
  group('ConversationSession', () {
    test('create factory generates unique ID and timestamp', () {
      final session1 = ConversationSession.create();
      final session2 = ConversationSession.create();

      expect(session1.id, isNotEmpty);
      expect(session2.id, isNotEmpty);
      expect(session1.id, isNot(equals(session2.id)));
      expect(session1.status, SessionStatus.created);
    });

    test('fullTranscript combines all segments', () {
      final session = ConversationSession.create().copyWith(
        segments: [
          const TranscriptSegment(
            text: 'Hello',
            timestamp: null,
          ),
          const TranscriptSegment(
            text: 'world',
            timestamp: null,
          ),
          const TranscriptSegment(
            text: 'test',
            timestamp: null,
          ),
        ],
      );

      expect(session.fullTranscript, 'Hello world test');
    });

    test('isActive returns true for recording/transcribing status', () {
      final recording = ConversationSession.create().copyWith(
        status: SessionStatus.recording,
      );
      final transcribing = ConversationSession.create().copyWith(
        status: SessionStatus.transcribing,
      );
      final completed = ConversationSession.create().copyWith(
        status: SessionStatus.completed,
      );

      expect(recording.isActive, true);
      expect(transcribing.isActive, true);
      expect(completed.isActive, false);
    });

    test('duration calculates correctly for completed session', () {
      final startTime = DateTime(2025, 1, 1, 10, 0, 0);
      final endTime = DateTime(2025, 1, 1, 10, 5, 30);

      final session = ConversationSession.create().copyWith(
        startTime: startTime,
        endTime: endTime,
        status: SessionStatus.completed,
      );

      expect(session.duration.inSeconds, 330);
    });

    test('serializes to JSON correctly', () {
      final session = ConversationSession.create().copyWith(
        segments: [
          TranscriptSegment.fromSpeechRecognition(
            text: 'Test',
            isFinal: true,
          ),
        ],
        status: SessionStatus.recording,
      );

      final json = session.toJson();

      expect(json['id'], isNotEmpty);
      expect(json['status'], 'recording');
      expect(json['segments'], isList);
    });

    test('deserializes from JSON correctly', () {
      final now = DateTime.now();
      final json = {
        'id': '123456',
        'startTime': now.toIso8601String(),
        'segments': [],
        'status': 'completed',
        'durationSeconds': 120,
      };

      final session = ConversationSession.fromJson(json);

      expect(session.id, '123456');
      expect(session.status, SessionStatus.completed);
      expect(session.durationSeconds, 120);
    });
  });
}
