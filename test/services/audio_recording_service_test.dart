import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_helix/services/audio_recording_service.dart';
import 'package:flutter_helix/services/implementations/mock_audio_service.dart';
import 'package:flutter_helix/services/implementations/mock_transcription_service.dart';
import 'package:flutter_helix/models/conversation_session.dart';

void main() {
  late AudioRecordingService recordingService;
  late MockAudioService mockAudio;
  late MockTranscriptionService mockTranscription;

  setUp(() {
    mockAudio = MockAudioService();
    mockTranscription = MockTranscriptionService();

    recordingService = AudioRecordingService(
      audioService: mockAudio,
      transcription: mockTranscription,
    );
  });

  tearDown(() {
    recordingService.dispose();
    mockAudio.dispose();
    mockTranscription.dispose();
  });

  group('AudioRecordingService Basic Recording', () {
    test('starts recording successfully', () async {
      final session = await recordingService.startRecording();

      expect(recordingService.isRecording, true);
      expect(session.status, SessionStatus.recording);
      expect(mockAudio.isRecording, true);
      expect(mockTranscription.isTranscribing, true);
    });

    test('stops recording and finalizes session', () async {
      await recordingService.startRecording();
      expect(recordingService.isRecording, true);

      final session = await recordingService.stopRecording();

      expect(recordingService.isRecording, false);
      expect(session.status, SessionStatus.completed);
      expect(session.endTime, isNotNull);
      expect(session.audioFilePath, isNotNull);
      expect(mockAudio.isRecording, false);
      expect(mockTranscription.isTranscribing, false);
    });

    test('throws error when starting recording twice', () async {
      await recordingService.startRecording();

      expect(
        () => recordingService.startRecording(),
        throwsStateError,
      );
    });

    test('throws error when stopping without starting', () {
      expect(
        () => recordingService.stopRecording(),
        throwsStateError,
      );
    });
  });

  group('AudioRecordingService Audio Streaming', () {
    test('streams audio levels during recording', () async {
      final levels = <double>[];
      final subscription = recordingService.audioLevelStream.listen(levels.add);

      await recordingService.startRecording();
      await Future.delayed(const Duration(milliseconds: 300));

      expect(levels, isNotEmpty);
      expect(levels.every((l) => l >= 0.0 && l <= 1.0), true);

      await recordingService.stopRecording();
      await subscription.cancel();
    });

    test('streams recording duration during recording', () async {
      final durations = <Duration>[];
      final subscription =
          recordingService.durationStream.listen(durations.add);

      await recordingService.startRecording();
      await Future.delayed(const Duration(milliseconds: 500));

      expect(durations, isNotEmpty);
      expect(durations.last.inMilliseconds, greaterThan(0));

      await recordingService.stopRecording();
      await subscription.cancel();
    });

    test('processes audio chunks for transcription', () async {
      await recordingService.startRecording();
      await Future.delayed(const Duration(milliseconds: 300));

      // Mock audio service generates audio data
      // Mock transcription service should receive chunks
      expect(mockTranscription.receivedAudioChunks, isNotEmpty);

      await recordingService.stopRecording();
    });
  });

  group('AudioRecordingService Pause/Resume', () {
    setUp(() async {
      await recordingService.startRecording();
    });

    test('pauses recording', () async {
      expect(mockAudio.isPaused, false);

      await recordingService.pauseRecording();

      expect(mockAudio.isPaused, true);
      expect(mockTranscription.isTranscribing, false);
    });

    test('resumes recording', () async {
      await recordingService.pauseRecording();
      expect(mockAudio.isPaused, true);

      await recordingService.resumeRecording();

      expect(mockAudio.isPaused, false);
      expect(mockTranscription.isTranscribing, true);
    });

    test('pause/resume does nothing if not recording', () async {
      await recordingService.stopRecording();

      // Should not throw
      await recordingService.pauseRecording();
      await recordingService.resumeRecording();
    });
  });

  group('AudioRecordingService Cancellation', () {
    test('cancels recording without saving', () async {
      await recordingService.startRecording();
      expect(recordingService.isRecording, true);

      await recordingService.cancelRecording();

      expect(recordingService.isRecording, false);
      expect(mockAudio.isRecording, false);
      expect(mockTranscription.isTranscribing, false);

      final session = recordingService.currentSession!;
      expect(session.status, SessionStatus.failed);
      expect(session.errorMessage, contains('cancelled'));
    });

    test('cancel does nothing if not recording', () async {
      // Should not throw
      await recordingService.cancelRecording();
    });
  });

  group('AudioRecordingService Error Handling', () {
    test('throws exception if audio recording fails to start', () async {
      mockAudio.failNextStart();

      expect(
        () => recordingService.startRecording(),
        throwsException,
      );
    });

    test('handles transcription errors gracefully', () async {
      mockTranscription.forcedTranscriptResult = 'Error text';

      await recordingService.startRecording();
      await Future.delayed(const Duration(milliseconds: 200));

      // Should continue recording despite transcription issues
      expect(recordingService.isRecording, true);

      await recordingService.stopRecording();
    });
  });

  group('AudioRecordingService Duration Tracking', () {
    test('tracks recording duration accurately', () async {
      await recordingService.startRecording();
      await Future.delayed(const Duration(milliseconds: 500));

      final duration = await recordingService.getRecordingDuration();

      expect(duration, isNotNull);
      expect(duration!.inMilliseconds, greaterThan(400));

      await recordingService.stopRecording();
    });

    test('session includes final duration after stopping', () async {
      await recordingService.startRecording();
      await Future.delayed(const Duration(milliseconds: 300));

      final session = await recordingService.stopRecording();

      expect(session.durationSeconds, greaterThan(0));
    });
  });

  group('AudioRecordingService Session Management', () {
    test('creates new session ID for each recording', () async {
      final session1 = await recordingService.startRecording();
      await recordingService.stopRecording();

      final session2 = await recordingService.startRecording();
      await recordingService.stopRecording();

      expect(session1.id, isNot(equals(session2.id)));
    });

    test('currentSession returns active session', () async {
      expect(recordingService.currentSession, isNull);

      await recordingService.startRecording();

      expect(recordingService.currentSession, isNotNull);
      expect(recordingService.currentSession!.status, SessionStatus.recording);
    });

    test('currentRecordingPath set during recording', () async {
      expect(recordingService.currentRecordingPath, isNull);

      await recordingService.startRecording();

      expect(recordingService.currentRecordingPath, isNotNull);
      expect(recordingService.currentRecordingPath, contains('recording_'));
    });
  });
}
