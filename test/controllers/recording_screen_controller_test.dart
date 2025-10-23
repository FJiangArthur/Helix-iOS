import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_helix/controllers/recording_screen_controller.dart';
import 'package:flutter_helix/services/audio_recording_service.dart';
import 'package:flutter_helix/services/implementations/mock_audio_service.dart';
import 'package:flutter_helix/services/implementations/mock_transcription_service.dart';
import 'package:flutter_helix/services/implementations/mock_ble_service.dart';
import 'package:flutter_helix/models/conversation_session.dart';

void main() {
  late RecordingScreenController controller;
  late AudioRecordingService recordingService;
  late MockAudioService mockAudio;
  late MockTranscriptionService mockTranscription;
  late MockBleService mockBle;

  setUp(() {
    mockAudio = MockAudioService();
    mockTranscription = MockTranscriptionService();
    mockBle = MockBleService();

    recordingService = AudioRecordingService(
      audioService: mockAudio,
      transcription: mockTranscription,
    );

    controller = RecordingScreenController(
      recordingService: recordingService,
      bleService: mockBle,
    );

    controller.onInit();
  });

  tearDown(() {
    controller.onClose();
    mockAudio.dispose();
    mockTranscription.dispose();
    mockBle.dispose();
  });

  group('RecordingScreenController Initialization', () {
    test('starts with correct initial state', () {
      expect(controller.isRecording.value, false);
      expect(controller.isPaused.value, false);
      expect(controller.audioLevel.value, 0.0);
      expect(controller.recordingDuration.value, Duration.zero);
      expect(controller.currentSession.value, isNull);
    });

    test('initializes glasses connection state', () {
      expect(controller.glassesConnection.value, isNotNull);
      expect(controller.isGlassesConnected, false);
    });
  });

  group('RecordingScreenController Recording Control', () {
    test('startRecording updates state correctly', () async {
      await controller.startRecording();

      expect(controller.isRecording.value, true);
      expect(controller.isPaused.value, false);
      expect(controller.currentSession.value, isNotNull);
      expect(controller.currentSession.value!.status, SessionStatus.recording);
    });

    test('stopRecording updates state correctly', () async {
      await controller.startRecording();
      await controller.stopRecording();

      expect(controller.isRecording.value, false);
      expect(controller.currentSession.value!.status, SessionStatus.completed);
      expect(controller.recordingDuration.value, Duration.zero);
      expect(controller.audioLevel.value, 0.0);
    });

    test('cannot start recording twice', () async {
      await controller.startRecording();
      final firstSession = controller.currentSession.value;

      await controller.startRecording(); // Try again

      // State should remain unchanged
      expect(controller.currentSession.value, same(firstSession));
    });

    test('toggleRecording starts when not recording', () async {
      expect(controller.isRecording.value, false);

      await controller.toggleRecording();

      expect(controller.isRecording.value, true);
    });

    test('toggleRecording stops when recording', () async {
      await controller.startRecording();
      expect(controller.isRecording.value, true);

      await controller.toggleRecording();

      expect(controller.isRecording.value, false);
    });
  });

  group('RecordingScreenController Pause/Resume', () {
    setUp(() async {
      await controller.startRecording();
    });

    test('pauseRecording updates state', () async {
      await controller.pauseRecording();

      expect(controller.isPaused.value, true);
      expect(controller.isRecording.value, true);
    });

    test('resumeRecording updates state', () async {
      await controller.pauseRecording();
      await controller.resumeRecording();

      expect(controller.isPaused.value, false);
      expect(controller.isRecording.value, true);
    });

    test('cannot pause when not recording', () async {
      await controller.stopRecording();

      // Should not throw
      await controller.pauseRecording();
      expect(controller.isPaused.value, false);
    });

    test('cannot resume when not paused', () async {
      // Should not throw
      await controller.resumeRecording();
      expect(controller.isPaused.value, false);
    });
  });

  group('RecordingScreenController Cancellation', () {
    test('cancelRecording clears state', () async {
      await controller.startRecording();
      await controller.cancelRecording();

      expect(controller.isRecording.value, false);
      expect(controller.isPaused.value, false);
      expect(controller.currentSession.value, isNull);
      expect(controller.recordingDuration.value, Duration.zero);
    });

    test('cancel does nothing when not recording', () async {
      // Should not throw
      await controller.cancelRecording();
      expect(controller.isRecording.value, false);
    });
  });

  group('RecordingScreenController Audio Streams', () {
    test('audioLevel updates from stream', () async {
      final levels = <double>[];
      controller.audioLevel.listen(levels.add);

      await controller.startRecording();
      await Future.delayed(const Duration(milliseconds: 200));

      expect(levels.length, greaterThan(1));
      expect(levels.last, greaterThan(0.0));

      await controller.stopRecording();
    });

    test('recordingDuration updates from stream', () async {
      final durations = <Duration>[];
      controller.recordingDuration.listen(durations.add);

      await controller.startRecording();
      await Future.delayed(const Duration(milliseconds: 300));

      expect(durations.length, greaterThan(1));
      expect(durations.last.inMilliseconds, greaterThan(0));

      await controller.stopRecording();
    });
  });

  group('RecordingScreenController Glasses Connection', () {
    test('updates connection status when glasses connect', () async {
      expect(controller.isGlassesConnected, false);

      await mockBle.connectToGlasses('G1-TEST');
      await Future.delayed(const Duration(milliseconds: 100));

      expect(controller.isGlassesConnected, true);
      expect(controller.glassesConnection.value!.deviceName, 'G1-TEST');
    });

    test('connectionStatusText reflects connection state', () async {
      expect(controller.connectionStatusText, 'Disconnected');

      await mockBle.connectToGlasses('G1-TEST');
      mockBle.setBatteryLevel(75);
      await Future.delayed(const Duration(milliseconds: 100));

      expect(controller.connectionStatusText, contains('G1-TEST'));
      expect(controller.connectionStatusText, contains('75%'));
    });
  });

  group('RecordingScreenController Formatting', () {
    test('formattedDuration formats correctly', () async {
      await controller.startRecording();

      // Manually set duration for testing
      controller.recordingDuration.value = const Duration(seconds: 125);

      expect(controller.formattedDuration, '02:05');

      controller.recordingDuration.value = const Duration(seconds: 5);
      expect(controller.formattedDuration, '00:05');

      await controller.stopRecording();
    });
  });

  group('RecordingScreenController Error Handling', () {
    test('handles start recording error', () async {
      mockAudio.failNextStart();

      try {
        await controller.startRecording();
        fail('Should have thrown exception');
      } catch (e) {
        // Expected
      }

      expect(controller.errorMessage.value, isNotNull);
      expect(controller.isRecording.value, false);
    });

    test('error message auto-clears after timeout', () async {
      mockAudio.failNextStart();

      try {
        await controller.startRecording();
      } catch (e) {
        // Expected
      }

      expect(controller.errorMessage.value, isNotNull);

      // Wait for auto-clear
      await Future.delayed(const Duration(seconds: 6));

      expect(controller.errorMessage.value, isNull);
    });

    test('clearError manually clears error', () async {
      mockAudio.failNextStart();

      try {
        await controller.startRecording();
      } catch (e) {
        // Expected
      }

      expect(controller.errorMessage.value, isNotNull);

      controller.clearError();

      expect(controller.errorMessage.value, isNull);
    });
  });
}
