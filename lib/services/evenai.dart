import 'dart:async';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import '../ble_manager.dart';
import '../utils/app_logger.dart';
import 'settings_manager.dart';
import 'audio_buffer_manager.dart';
import 'text_paginator.dart';
import 'hud_controller.dart';
import 'conversation_engine.dart';

/// Even AI coordinator service for conversation analysis
/// Coordinates audio buffering, text pagination, and HUD display
class EvenAI {
  static EvenAI? _instance;
  static EvenAI get get => _instance ??= EvenAI._();

  EvenAI._();

  // Delegate services
  final _audioBuffer = AudioBufferManager.instance;
  final _textPaginator = TextPaginator.instance;
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

  static const _eventSpeechRecognize = "eventSpeechRecognize";
  final _eventSpeechRecognizeChannel = const EventChannel(
    _eventSpeechRecognize,
  ).receiveBroadcastStream(_eventSpeechRecognize);

  String combinedText = '';
  StreamSubscription? _speechSubscription;
  Completer<void>? _speechFinalizationCompleter;
  String _lastFinalizedText = '';

  /// Send text to AI stream
  void updateText(String text) {
    _hudController.updateDisplay(text);
  }

  void updateDynamicText(String newText) {
    _hudController.updateDisplay(newText);
  }

  /// Start AI processing
  static void startProcessing() {
    isEvenAISyncing.value = true;
  }

  /// Stop AI processing
  static void stopProcessing() {
    isEvenAISyncing.value = false;
  }

  void startListening() {
    combinedText = '';
    _lastFinalizedText = '';
    _speechFinalizationCompleter = Completer<void>();
    _speechSubscription?.cancel();
    _speechSubscription = _eventSpeechRecognizeChannel.listen(
      (event) {
        final payload = Map<String, dynamic>.from(event as Map);
        final txt = (payload["script"] as String? ?? '').trim();
        final isFinal = payload["isFinal"] == true;

        if (txt.isNotEmpty) {
          combinedText = txt;
          updateDynamicText(txt);
          _processTranscribedText(txt);
        }

        if (isFinal) {
          _finalizeRecognizedText(txt.isNotEmpty ? txt : combinedText);
        }
      },
      onError: (error) {
        appLogger.e("Error in speech recognition event: $error");
        _completeSpeechFinalization();
      },
    );
  }

  void _processTranscribedText(String text) {
    // Paginate text for glasses display
    _textPaginator.paginateText(text);
    _updateDisplay();

    // Feed into conversation engine for question detection & AI
    ConversationEngine.instance.onTranscriptionUpdate(text);
  }

  /// Receiving starting Even AI request from BLE
  void toStartEvenAIByOS() async {
    // Restart to avoid BLE data conflict
    BleManager.get().startSendBeatHeart();

    // Start conversation engine
    ConversationEngine.instance.start();

    startListening();

    // Avoid duplicate BLE command in short time, especially Android
    int currentTime = DateTime.now().millisecondsSinceEpoch;
    if (currentTime - _lastStartTime < startTimeGap) {
      return;
    }

    _lastStartTime = currentTime;

    clear();
    _audioBuffer.startReceiving();

    isRunning = true;

    final langCode = _getLanguageCode();
    await BleManager.invokeMethod("startEvenAI", {
      "language": langCode,
      "source": "glasses",
    });

    await _hudController.beginLiveListening(source: 'EvenAI.toStartEvenAIByOS');
    updateDynamicText("");

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

    await BleManager.invokeMethod("stopEvenAI");
    await _waitForSpeechFinalization();
    _speechSubscription?.cancel();
    _speechSubscription = null;
    _audioBuffer.stopReceiving();
    await _hudController.resetToIdle(
      source: 'EvenAI.stopEvenAIByOS',
      hideScreen: true,
    );

    // Stop conversation engine
    ConversationEngine.instance.stop();

    clear();
  }

  /// Recording ended by OS
  void recordOverByOS() async {
    if (!isRunning) return;

    _stopRecordingTimer();
    _audioBuffer.stopReceiving();
    appLogger.d("Recording completed with ${_audioBuffer.bufferSize} bytes");
    _finalizeRecognizedText(combinedText);
    _audioBuffer.clear();
  }

  /// Navigate to last page by touchpad
  void lastPageByTouchpad() {
    if (!isRunning) return;

    if (_textPaginator.previousPage()) {
      _updateDisplay();
    }
  }

  /// Navigate to next page by touchpad
  void nextPageByTouchpad() {
    if (!isRunning) return;

    if (_textPaginator.nextPage()) {
      _updateDisplay();
    }
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

  void _updateDisplay() {
    updateDynamicText(_textPaginator.currentPageText);
  }

  void clear() {
    _audioBuffer.clear();
    _textPaginator.clear();
    sendReplys.clear();
  }

  void _finalizeRecognizedText(String text) {
    final normalized = text.trim();
    if (normalized.isEmpty || normalized == _lastFinalizedText) {
      _completeSpeechFinalization();
      return;
    }

    _lastFinalizedText = normalized;
    ConversationEngine.instance.onTranscriptionFinalized(normalized);
    _completeSpeechFinalization();
  }

  Future<void> _waitForSpeechFinalization() async {
    final waiter = _speechFinalizationCompleter;
    if (waiter == null || waiter.isCompleted) {
      return;
    }

    try {
      await waiter.future.timeout(const Duration(milliseconds: 1500));
    } catch (_) {
      _completeSpeechFinalization();
    }
  }

  void _completeSpeechFinalization() {
    final waiter = _speechFinalizationCompleter;
    if (waiter != null && !waiter.isCompleted) {
      waiter.complete();
    }
  }

  /// Map settings language to native speech recognizer identifier
  String _getLanguageCode() {
    final lang = SettingsManager.instance.language;
    switch (lang) {
      case 'zh':
        return 'CN';
      case 'ja':
        return 'JP';
      case 'ko':
        return 'KR';
      case 'es':
        return 'ES';
      case 'ru':
        return 'RU';
      default:
        return 'EN';
    }
  }

  /// Dispose resources
  void dispose() {
    _speechSubscription?.cancel();
    _speechSubscription = null;
    _hudController.dispose();
    _audioBuffer.dispose();
  }
}
