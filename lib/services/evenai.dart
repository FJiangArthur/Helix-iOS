import 'dart:async';
import 'package:get/get.dart';

/// Even AI service for conversation analysis
class EvenAI {
  static final StreamController<String> _textStreamController = 
      StreamController<String>.broadcast();
  
  static Stream<String> get textStream => _textStreamController.stream;
  
  static RxBool isEvenAISyncing = false.obs;
  
  /// Send text to AI stream
  static void updateText(String text) {
    _textStreamController.add(text);
  }
  
  /// Start AI processing
  static void startProcessing() {
    isEvenAISyncing.value = true;
  }
  
  /// Stop AI processing
  static void stopProcessing() {
    isEvenAISyncing.value = false;
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