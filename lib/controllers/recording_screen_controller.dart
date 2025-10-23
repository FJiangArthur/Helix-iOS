import 'dart:async';
import 'package:get/get.dart';
import '../models/conversation_session.dart';
import '../models/glasses_connection.dart';
import '../services/audio_recording_service.dart';
import '../services/interfaces/i_ble_service.dart';

/// Controller for recording screen state management
/// Uses GetX for reactive state management
class RecordingScreenController extends GetxController {
  final AudioRecordingService _recordingService;
  final IBleService _bleService;

  // Observable state
  final isRecording = false.obs;
  final isPaused = false.obs;
  final audioLevel = 0.0.obs;
  final recordingDuration = Duration.zero.obs;
  final currentSession = Rx<ConversationSession?>(null);
  final glassesConnection = Rx<GlassesConnection?>(null);
  final errorMessage = Rx<String?>(null);

  StreamSubscription<double>? _audioLevelSubscription;
  StreamSubscription<Duration>? _durationSubscription;
  StreamSubscription<GlassesConnection>? _connectionSubscription;

  RecordingScreenController({
    required AudioRecordingService recordingService,
    required IBleService bleService,
  })  : _recordingService = recordingService,
        _bleService = bleService;

  @override
  void onInit() {
    super.onInit();
    _setupStreams();
  }

  @override
  void onClose() {
    _audioLevelSubscription?.cancel();
    _durationSubscription?.cancel();
    _connectionSubscription?.cancel();
    super.onClose();
  }

  /// Setup reactive streams
  void _setupStreams() {
    // Listen to audio level changes
    _audioLevelSubscription = _recordingService.audioLevelStream.listen(
      (level) {
        audioLevel.value = level;
      },
      onError: (error) {
        _handleError('Audio level error: $error');
      },
    );

    // Listen to recording duration
    _durationSubscription = _recordingService.durationStream.listen(
      (duration) {
        recordingDuration.value = duration;
      },
      onError: (error) {
        _handleError('Duration tracking error: $error');
      },
    );

    // Listen to glasses connection status
    _connectionSubscription = _bleService.connectionStream.listen(
      (connection) {
        glassesConnection.value = connection;
      },
      onError: (error) {
        _handleError('Connection error: $error');
      },
    );

    // Set initial connection state
    glassesConnection.value = _bleService.currentConnection;
  }

  /// Start recording
  Future<void> startRecording() async {
    if (isRecording.value) return;

    try {
      errorMessage.value = null;

      final session = await _recordingService.startRecording();

      isRecording.value = true;
      isPaused.value = false;
      currentSession.value = session;
    } catch (e) {
      _handleError('Failed to start recording: $e');
      rethrow;
    }
  }

  /// Stop recording
  Future<void> stopRecording() async {
    if (!isRecording.value) return;

    try {
      final session = await _recordingService.stopRecording();

      isRecording.value = false;
      isPaused.value = false;
      currentSession.value = session;
      recordingDuration.value = Duration.zero;
      audioLevel.value = 0.0;
    } catch (e) {
      _handleError('Failed to stop recording: $e');
      rethrow;
    }
  }

  /// Pause recording
  Future<void> pauseRecording() async {
    if (!isRecording.value || isPaused.value) return;

    try {
      await _recordingService.pauseRecording();
      isPaused.value = true;
    } catch (e) {
      _handleError('Failed to pause recording: $e');
    }
  }

  /// Resume recording
  Future<void> resumeRecording() async {
    if (!isRecording.value || !isPaused.value) return;

    try {
      await _recordingService.resumeRecording();
      isPaused.value = false;
    } catch (e) {
      _handleError('Failed to resume recording: $e');
    }
  }

  /// Cancel recording
  Future<void> cancelRecording() async {
    if (!isRecording.value) return;

    try {
      await _recordingService.cancelRecording();

      isRecording.value = false;
      isPaused.value = false;
      currentSession.value = null;
      recordingDuration.value = Duration.zero;
      audioLevel.value = 0.0;
    } catch (e) {
      _handleError('Failed to cancel recording: $e');
    }
  }

  /// Toggle recording (start/stop)
  Future<void> toggleRecording() async {
    if (isRecording.value) {
      await stopRecording();
    } else {
      await startRecording();
    }
  }

  /// Format duration for display
  String get formattedDuration {
    final duration = recordingDuration.value;
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  /// Check if glasses are connected
  bool get isGlassesConnected =>
      glassesConnection.value?.isConnected ?? false;

  /// Get connection status text
  String get connectionStatusText {
    final connection = glassesConnection.value;
    if (connection == null || !connection.isConnected) {
      return 'Disconnected';
    }
    return '${connection.deviceName} - ${connection.batteryLevel}%';
  }

  /// Handle errors
  void _handleError(String message) {
    errorMessage.value = message;
    print('RecordingScreenController error: $message');

    // Auto-clear error after 5 seconds
    Future.delayed(const Duration(seconds: 5), () {
      if (errorMessage.value == message) {
        errorMessage.value = null;
      }
    });
  }

  /// Clear error message
  void clearError() {
    errorMessage.value = null;
  }
}
