import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_helix/services/transcription/native_transcription_service.dart';
import 'package:flutter_helix/services/transcription/transcription_models.dart';

void main() {
  group('NativeTranscriptionService', () {
    late NativeTranscriptionService service;

    setUp(() {
      service = NativeTranscriptionService.instance;
    });

    test('has correct mode', () {
      expect(service.mode, TranscriptionMode.native);
    });

    test('starts not transcribing', () {
      expect(service.isTranscribing, false);
    });

    test('initialize marks service as available', () async {
      await service.initialize();
      expect(service.isAvailable, true);
    });

    test('getStats returns valid statistics', () {
      final stats = service.getStats();

      expect(stats.segmentCount, greaterThanOrEqualTo(0));
      expect(stats.totalCharacters, greaterThanOrEqualTo(0));
      expect(stats.activeMode, TranscriptionMode.native);
      expect(stats.averageConfidence, greaterThanOrEqualTo(0.0));
      expect(stats.averageConfidence, lessThanOrEqualTo(1.0));
    });

    test('transcriptStream is not null', () {
      expect(service.transcriptStream, isNotNull);
    });

    test('errorStream is not null', () {
      expect(service.errorStream, isNotNull);
    });

    test('dispose does not throw', () {
      expect(() => service.dispose(), returnsNormally);
    });
  });
}
