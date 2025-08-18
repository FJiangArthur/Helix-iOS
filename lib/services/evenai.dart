import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import '../ble_manager.dart';
import 'proto.dart';

/// Even AI service for conversation analysis
class EvenAI {
  static EvenAI? _instance;
  static EvenAI get get => _instance ??= EvenAI._();
  
  EvenAI._();
  
  static bool _isRunning = false;
  static bool get isRunning => _isRunning;
  
  bool isReceivingAudio = false;
  List<int> audioDataBuffer = [];
  Uint8List? audioData;
  
  File? lc3File;
  File? pcmFile;
  int durationS = 0;
  
  static int maxRetry = 10;
  static int _currentLine = 0;
  static Timer? _timer;
  static List<String> list = [];
  static List<String> sendReplys = [];
  
  Timer? _recordingTimer;
  final int maxRecordingDuration = 30;
  
  static bool _isManual = false;
  
  static set isRunning(bool value) {
    _isRunning = value;
    isEvenAIOpen.value = value;
    isEvenAISyncing.value = value;
  }
  
  static RxBool isEvenAIOpen = false.obs;
  static final StreamController<String> _textStreamController = 
      StreamController<String>.broadcast();
  
  static Stream<String> get textStream => _textStreamController.stream;
  
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
  static void updateText(String text) {
    _textStreamController.add(text);
  }
  
  static void updateDynamicText(String newText) {
    _textStreamController.add(newText);
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
    // Split text into displayable lines for glasses
    list = EvenAIDataMethod.measureStringList(text);
    _currentLine = 0;
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
    isReceivingAudio = true;
    
    isRunning = true;
    _currentLine = 0;
    
    await BleManager.invokeMethod("startEvenAI");
    
    Proto.pushScreen(0x01);
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
    isReceivingAudio = false;
    
    _stopRecordingTimer();
    _timer?.cancel();
    _timer = null;
    
    await BleManager.invokeMethod("stopEvenAI");
    await Proto.pushScreen(0x00);
    
    clear();
  }
  
  /// Recording ended by OS
  void recordOverByOS() async {
    if (!isRunning) return;
    
    _stopRecordingTimer();
    
    isReceivingAudio = false;
    
    if (audioDataBuffer.isEmpty) {
      print("No audio data received");
      return;
    }
    
    // Process audio data here
    print("Recording completed with ${audioDataBuffer.length} bytes");
    
    // Clear buffer after processing
    audioDataBuffer.clear();
  }
  
  /// Navigate to last page by touchpad
  void lastPageByTouchpad() {
    if (!isRunning) return;
    
    if (_currentLine > 0) {
      _currentLine--;
      _updateDisplay();
    }
  }
  
  /// Navigate to next page by touchpad
  void nextPageByTouchpad() {
    if (!isRunning) return;
    
    if (_currentLine < list.length - 1) {
      _currentLine++;
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
    if (list.isNotEmpty && _currentLine < list.length) {
      updateDynamicText(list[_currentLine]);
    }
  }
  
  void clear() {
    audioDataBuffer.clear();
    audioData = null;
    list.clear();
    sendReplys.clear();
    _currentLine = 0;
    durationS = 0;
  }
  
  /// Dispose resources
  static void dispose() {
    _textStreamController.close();
  }
}

/// AI data processing methods
class EvenAIDataMethod {
  /// Split text into lines for display
  static List<String> measureStringList(String text) {
    // Split text into manageable chunks for glasses display
    const maxLineLength = 40; // Approximate characters per line for G1 glasses
    
    final words = text.split(' ');
    final lines = <String>[];
    var currentLine = '';
    
    for (final word in words) {
      if (currentLine.isEmpty) {
        currentLine = word;
      } else if ((currentLine + ' ' + word).length <= maxLineLength) {
        currentLine += ' ' + word;
      } else {
        lines.add(currentLine);
        currentLine = word;
      }
    }
    
    if (currentLine.isNotEmpty) {
      lines.add(currentLine);
    }
    
    return lines;
  }
  
  /// Convert type and status to new screen format
  static int transferToNewScreen(int type, int status) {
    // Convert display parameters to Even Realities format
    return (type << 4) | (status & 0x0F);
  }
}