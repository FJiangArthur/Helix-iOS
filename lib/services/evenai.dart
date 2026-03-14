import 'dart:async';
import 'package:get/get.dart';
import '../ble_manager.dart';
import '../utils/app_logger.dart';
import 'audio_buffer_manager.dart';
import 'conversation_engine.dart';
import 'conversation_listening_session.dart';
import 'hud_controller.dart';

/// Even AI coordinator service for conversation analysis
/// Coordinates glasses-specific audio capture and session state.
class EvenAI {
  static EvenAI? _instance;
  static EvenAI get get => _instance ??= EvenAI._();

  EvenAI._();

  // Delegate services
  final _audioBuffer = AudioBufferManager.instance;
  final _hudController = HudController.instance;

  static bool _isRunning = false;
  static bool get isRunning => _isRunning;

  static int maxRetry = 10;
  static Timer? _timer;
  static List<String> sendReplys = [];

  Timer? _recordingTimer;
  final int maxRecordingDuration = 30;

  static set isRunning(bool value) {
    _isRunning = value;
    isEvenAIOpen.value = value;
    isEvenAISyncing.value = value;
  }

  static RxBool isEvenAIOpen = false.obs;

  /// Text stream from HUD controller
  Stream<String> get textStream => _hudController.displayTextStream;

  static RxBool isEvenAISyncing = false.obs;

  int _lastStartTime = 0;
  int _lastStopTime = 0;
  final int startTimeGap = 500;
  final int stopTimeGap = 500;

  /// Start AI processing
  static void startProcessing() {
    isEvenAISyncing.value = true;
  }

  /// Stop AI processing
  static void stopProcessing() {
    isEvenAISyncing.value = false;
  }

  /// Receiving starting Even AI request from BLE
  Future<void> toStartEvenAIByOS() async {
    // Avoid duplicate BLE command in short time, especially Android
    int currentTime = DateTime.now().millisecondsSinceEpoch;
    if (currentTime - _lastStartTime < startTimeGap) {
      return;
    }

    _lastStartTime = currentTime;

    // Restart to avoid BLE data conflict
    BleManager.get().startSendBeatHeart();

    clear();
    _audioBuffer.startReceiving();

    isRunning = true;
    await ConversationListeningSession.instance.startSession(
      source: TranscriptSource.glasses,
    );

    await _hudController.beginLiveListening(source: 'EvenAI.toStartEvenAIByOS');

    _startRecordingTimer();
  }

  /// Stop Even AI by OS command
  Future<void> stopEvenAIByOS() async {
    int currentTime = DateTime.now().millisecondsSinceEpoch;
    if (currentTime - _lastStopTime < stopTimeGap) {
      return;
    }
    _lastStopTime = currentTime;

    isRunning = false;
    _stopRecordingTimer();
    _timer?.cancel();
    _timer = null;

    await ConversationListeningSession.instance.stopSession();
    _audioBuffer.stopReceiving();
    await _hudController.resetToIdle(
      source: 'EvenAI.stopEvenAIByOS',
      hideScreen: true,
    );

    clear();
  }

  /// Recording ended by OS
  void recordOverByOS() async {
    if (!isRunning) return;

    _stopRecordingTimer();
    _audioBuffer.stopReceiving();
    appLogger.d("Recording completed with ${_audioBuffer.bufferSize} bytes");
    ConversationListeningSession.instance.finalizePendingTranscript();
    _audioBuffer.clear();
  }

  /// Navigate to last page by touchpad
  void lastPageByTouchpad() {
    // Live listening answers are paced automatically.
  }

  /// Navigate to next page by touchpad
  void nextPageByTouchpad() {
    // Live listening answers are paced automatically.
  }

  void _startRecordingTimer() {
    _recordingTimer?.cancel();
    _recordingTimer = Timer(Duration(seconds: maxRecordingDuration), () {
      recordOverByOS();
    });
  }

  void _stopRecordingTimer() {
    _recordingTimer?.cancel();
    _recordingTimer = null;
  }

  void clear() {
    _audioBuffer.clear();
    sendReplys.clear();
  }

  /// Dispose resources
  void dispose() {
    _hudController.dispose();
    _audioBuffer.dispose();
  }
}
