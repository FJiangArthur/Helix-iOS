import 'dart:async';
import 'package:get/get.dart';
import '../ble_manager.dart';
import '../utils/app_logger.dart';
import 'audio_buffer_manager.dart';
import 'conversation_engine.dart';
import 'conversation_listening_session.dart';
import 'glasses_answer_presenter.dart';
import 'glasses_protocol.dart';
import 'hud_controller.dart';
import 'hud_intent.dart';
import 'proto.dart';

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

  /// Pause/resume state for live listening
  static bool _isPaused = false;

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
    _isPaused = false;
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
    _isPaused = false;
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
  Future<void> recordOverByOS() async {
    if (!isRunning) return;

    _isPaused = false;
    _stopRecordingTimer();
    _audioBuffer.stopReceiving();
    appLogger.d("Recording completed with ${_audioBuffer.bufferSize} bytes");
    ConversationListeningSession.instance.finalizePendingTranscript();
    _audioBuffer.clear();
    isRunning = false;
    await ConversationListeningSession.instance.stopSession();
  }

  /// Context-aware left touch handler (page back / pause / dismiss)
  static void handleLeftTouch() {
    final intent = HudController.instance.currentIntent;
    appLogger.d('[EvenAI] handleLeftTouch — intent=${intent.name}');
    switch (intent) {
      case HudIntent.liveListening:
        _togglePauseResume();
        break;
      case HudIntent.quickAsk:
        GlassesAnswerPresenter.instance.previousPage();
        break;
      case HudIntent.dashboard:
      case HudIntent.notification:
        HudController.instance.resetToIdle(
          source: 'EvenAI.handleLeftTouch',
        );
        break;
      case HudIntent.textTransfer:
        // existing page back behavior — no-op, auto-paced
        break;
      default:
        break;
    }
  }

  /// Context-aware right touch handler (page forward / analyze / dismiss)
  static void handleRightTouch() {
    final intent = HudController.instance.currentIntent;
    appLogger.d('[EvenAI] handleRightTouch — intent=${intent.name}');
    switch (intent) {
      case HudIntent.liveListening:
        _triggerManualQuestionDetection();
        break;
      case HudIntent.quickAsk:
        GlassesAnswerPresenter.instance.nextPage();
        break;
      case HudIntent.dashboard:
      case HudIntent.notification:
        HudController.instance.resetToIdle(
          source: 'EvenAI.handleRightTouch',
        );
        break;
      case HudIntent.textTransfer:
        // existing page forward behavior — no-op, auto-paced
        break;
      default:
        break;
    }
  }

  /// Navigate to last page by touchpad (delegates to context-aware handler)
  void lastPageByTouchpad() {
    handleLeftTouch();
  }

  /// Navigate to next page by touchpad (delegates to context-aware handler)
  void nextPageByTouchpad() {
    handleRightTouch();
  }

  /// Toggle pause/resume for live listening transcription
  static void _togglePauseResume() {
    if (_isPaused) {
      ConversationListeningSession.instance.resumeTranscription();
      _isPaused = false;
      _flashFeedback('RESUMED');
    } else {
      ConversationListeningSession.instance.pauseTranscription();
      _isPaused = true;
      _flashFeedback('PAUSED');
    }
  }

  /// Manually trigger question detection from glasses button press
  static void _triggerManualQuestionDetection() {
    ConversationEngine.instance.forceQuestionAnalysis();
    _flashFeedback('ANALYZING...');
  }

  /// Show brief feedback text on glasses display, auto-clears after 500ms
  static void _flashFeedback(String text) async {
    appLogger.d('[EvenAI] Flash feedback: $text');
    await Proto.sendEvenAIData(
      text,
      newScreen: HudDisplayState.textPage(),
      pos: 0,
      current_page_num: 1,
      max_page_num: 1,
    );
    // Auto-dismiss after 500ms by clearing the overlay screen
    Future.delayed(const Duration(milliseconds: 500), () {
      Proto.pushScreen(0x00);
    });
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

  /// Dispose resources owned by this instance (not shared singletons).
  void dispose() {
    _stopRecordingTimer();
    _recordingTimer?.cancel();
  }
}
