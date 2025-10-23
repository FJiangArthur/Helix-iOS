import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_helix/models/transcript_segment.dart';

void main() {
  group('TranscriptSegment', () {
    test('creates segment with required fields', () {
      final now = DateTime.now();
      final segment = TranscriptSegment(
        text: 'Hello world',
        timestamp: now,
      );

      expect(segment.text, 'Hello world');
      expect(segment.timestamp, now);
      expect(segment.confidence, 1.0);
      expect(segment.isFinal, false);
    });

    test('fromSpeechRecognition factory creates correct segment', () {
      final segment = TranscriptSegment.fromSpeechRecognition(
        text: 'Test transcript',
        isFinal: true,
      );

      expect(segment.text, 'Test transcript');
      expect(segment.isFinal, true);
      expect(segment.confidence, 0.95);
      expect(segment.timestamp, isNotNull);
    });

    test('serializes to JSON correctly', () {
      final segment = TranscriptSegment(
        text: 'Test',
        timestamp: DateTime(2025, 1, 1, 10, 0, 0),
        confidence: 0.9,
        isFinal: true,
        speakerId: 1,
      );

      final json = segment.toJson();

      expect(json['text'], 'Test');
      expect(json['confidence'], 0.9);
      expect(json['isFinal'], true);
      expect(json['speakerId'], 1);
    });

    test('deserializes from JSON correctly', () {
      final json = {
        'text': 'Deserialized text',
        'timestamp': DateTime(2025, 1, 1, 10, 0, 0).toIso8601String(),
        'confidence': 0.85,
        'isFinal': true,
      };

      final segment = TranscriptSegment.fromJson(json);

      expect(segment.text, 'Deserialized text');
      expect(segment.confidence, 0.85);
      expect(segment.isFinal, true);
    });

    test('copyWith creates modified copy', () {
      final original = TranscriptSegment.fromSpeechRecognition(
        text: 'Original',
        isFinal: false,
      );

      final updated = original.copyWith(
        text: 'Updated',
        isFinal: true,
      );

      expect(original.text, 'Original');
      expect(original.isFinal, false);
      expect(updated.text, 'Updated');
      expect(updated.isFinal, true);
    });
  });
}
