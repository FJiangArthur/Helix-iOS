import 'dart:async';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import '../ble_manager.dart';
import 'audio_buffer_manager.dart';
import 'text_paginator.dart';
import 'hud_controller.dart';

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
  final _eventSpeechRecognizeChannel = 
      const EventChannel(_eventSpeechRecognize).receiveBroadcastStream(_eventSpeechRecognize);
  
  String combinedText = '';
  
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
    _eventSpeechRecognizeChannel.listen((event) {
      var txt = event["script"] as String;
      combinedText = txt;
      
      // Update the text stream for UI
      updateDynamicText(txt);
      
      // Process the text for AI analysis if needed
      if (txt.isNotEmpty) {
        _processTranscribedText(txt);
      }
    }, onError: (error) {
      print("Error in speech recognition event: $error");
    });
  }
  
  void _processTranscribedText(String text) {
    // Paginate text for glasses display
    _textPaginator.paginateText(text);
    _updateDisplay();
  }
  
  /// Receiving starting Even AI request from BLE
  void toStartEvenAIByOS() async {
    // Restart to avoid BLE data conflict
    BleManager.get().startSendBeatHeart();
    
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

    await BleManager.invokeMethod("startEvenAI");

    await _hudController.showEvenAIScreen();
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
    _audioBuffer.stopReceiving();

    _stopRecordingTimer();
    _timer?.cancel();
    _timer = null;

    await BleManager.invokeMethod("stopEvenAI");
    await _hudController.hideEvenAIScreen();

    clear();
  }
  
  /// Recording ended by OS
  void recordOverByOS() async {
    if (!isRunning) return;

    _stopRecordingTimer();

    _audioBuffer.stopReceiving();

    if (_audioBuffer.isEmpty) {
      print("No audio data received");
      return;
    }

    // Process audio data here
    print("Recording completed with ${_audioBuffer.bufferSize} bytes");

    // Clear buffer after processing
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

  /// Dispose resources
  void dispose() {
    _hudController.dispose();
    _audioBuffer.dispose();
  }
}