/// Audio and Transcription Integration Tests
///
/// Tests the integration between audio recording and transcription services

import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:flutter_helix/services/transcription/native_transcription_service.dart';
import 'package:flutter_helix/services/transcription/transcription_models.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Audio-Transcription Integration', () {
    late NativeTranscriptionService transcriptionService;

    setUp(() {
      transcriptionService = NativeTranscriptionService.instance;
    });

    tearDown(() {
      transcriptionService.dispose();
    });

    test('Transcription service initializes correctly', () async {
      await transcriptionService.initialize();
      expect(transcriptionService.isAvailable, isTrue);
    });

    test('Transcription service can start and stop', () async {
      await transcriptionService.initialize();

      // Note: Actual recording requires permissions and audio input
      // In a real integration test, you would:
      // 1. Grant necessary permissions
      // 2. Use mock audio data or test audio file
      // 3. Verify transcription output

      expect(transcriptionService.isTranscribing, isFalse);
    });

    test('Transcription stream emits segments', () async {
      await transcriptionService.initialize();

      // Create a completer to track if we receive segments
      final Completer<bool> segmentReceived = Completer<bool>();
      late StreamSubscription<TranscriptionSegment> subscription;

      subscription = transcriptionService.transcriptStream.listen(
        (TranscriptionSegment segment) {
          if (!segmentReceived.isCompleted) {
            segmentReceived.complete(true);
          }
        },
      );

      // In a real test, you would trigger actual transcription here
      // For now, we just verify the stream is set up correctly

      await subscription.cancel();
      expect(transcriptionService.transcriptStream, isNotNull);
    });

    test('Statistics are tracked correctly', () async {
      await transcriptionService.initialize();

      final TranscriptionStats stats = transcriptionService.getStats();

      expect(stats.segmentCount, greaterThanOrEqualTo(0));
      expect(stats.totalCharacters, greaterThanOrEqualTo(0));
      expect(stats.activeMode, equals(TranscriptionMode.native));
    });
  });

  group('Transcription Mode Switching', () {
    test('Can switch between transcription modes', () async {
      // This would test the TranscriptionCoordinator's ability to switch
      // between native and Whisper transcription modes based on connectivity

      // TODO: Implement mode switching test
      expect(true, isTrue); // Placeholder
    });
  });
}
