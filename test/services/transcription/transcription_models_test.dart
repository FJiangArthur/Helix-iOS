import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_helix/services/transcription/transcription_models.dart';

void main() {
  group('TranscriptSegment', () {
    test('creates segment with required fields', () {
      final segment = TranscriptSegment(
        text: 'Hello world',
        confidence: 0.95,
        timestamp: DateTime.now(),
        source: TranscriptionMode.native,
      );

      expect(segment.text, 'Hello world');
      expect(segment.confidence, 0.95);
      expect(segment.isFinal, false); // Default
      expect(segment.source, TranscriptionMode.native);
    });

    test('copyWith creates modified copy', () {
      final original = TranscriptSegment(
        text: 'Original',
        confidence: 0.8,
        timestamp: DateTime.now(),
        source: TranscriptionMode.native,
      );

      final modified = original.copyWith(
        text: 'Modified',
        isFinal: true,
      );

      expect(modified.text, 'Modified');
      expect(modified.confidence, 0.8); // Unchanged
      expect(modified.isFinal, true);
    });

    test('equality works correctly', () {
      final timestamp = DateTime.now();
      final segment1 = TranscriptSegment(
        text: 'Test',
        confidence: 0.9,
        timestamp: timestamp,
        source: TranscriptionMode.native,
      );

      final segment2 = TranscriptSegment(
        text: 'Test',
        confidence: 0.9,
        timestamp: timestamp,
        source: TranscriptionMode.native,
      );

      expect(segment1, equals(segment2));
      expect(segment1.hashCode, equals(segment2.hashCode));
    });
  });

  group('TranscriptionError', () {
    test('creates error with type and message', () {
      const error = TranscriptionError(
        type: TranscriptionErrorType.networkError,
        message: 'Network unavailable',
      );

      expect(error.type, TranscriptionErrorType.networkError);
      expect(error.message, 'Network unavailable');
      expect(error.toString(), contains('networkError'));
    });

    test('includes original error if provided', () {
      final originalError = Exception('Original');
      final error = TranscriptionError(
        type: TranscriptionErrorType.apiError,
        message: 'API failed',
        originalError: originalError,
      );

      expect(error.originalError, originalError);
    });
  });

  group('TranscriptionStats', () {
    test('creates stats with correct fields', () {
      final stats = TranscriptionStats(
        segmentCount: 10,
        totalCharacters: 500,
        totalDuration: const Duration(minutes: 5),
        averageConfidence: 0.92,
        activeMode: TranscriptionMode.whisper,
      );

      expect(stats.segmentCount, 10);
      expect(stats.totalCharacters, 500);
      expect(stats.totalDuration.inMinutes, 5);
      expect(stats.averageConfidence, 0.92);
      expect(stats.activeMode, TranscriptionMode.whisper);
    });

    test('toJson converts to map correctly', () {
      final stats = TranscriptionStats(
        segmentCount: 5,
        totalCharacters: 250,
        totalDuration: const Duration(seconds: 30),
        averageConfidence: 0.88,
        activeMode: TranscriptionMode.native,
      );

      final json = stats.toJson();

      expect(json['segmentCount'], 5);
      expect(json['totalCharacters'], 250);
      expect(json['totalDurationMs'], 30000);
      expect(json['averageConfidence'], 0.88);
      expect(json['activeMode'], contains('native'));
    });
  });

  group('TranscriptionMode', () {
    test('has all expected modes', () {
      expect(TranscriptionMode.values.length, 3);
      expect(TranscriptionMode.values, contains(TranscriptionMode.native));
      expect(TranscriptionMode.values, contains(TranscriptionMode.whisper));
      expect(TranscriptionMode.values, contains(TranscriptionMode.auto));
    });
  });

  group('TranscriptionErrorType', () {
    test('has all expected error types', () {
      expect(TranscriptionErrorType.values.length, 6);
      expect(TranscriptionErrorType.values,
          contains(TranscriptionErrorType.notAuthorized));
      expect(TranscriptionErrorType.values,
          contains(TranscriptionErrorType.networkError));
      expect(TranscriptionErrorType.values,
          contains(TranscriptionErrorType.apiError));
    });
  });
}
