import 'dart:async';
import 'proto.dart';

/// Controls HUD display and screen management for G1 glasses
class HudController {
  HudController._();

  static HudController? _instance;
  static HudController get instance => _instance ??= HudController._();

  final StreamController<String> _displayTextController =
      StreamController<String>.broadcast();

  /// Stream of text to display on HUD
  Stream<String> get displayTextStream => _displayTextController.stream;

  /// Update HUD with new text
  void updateDisplay(String text) {
    _displayTextController.add(text);
  }

  /// Push screen command to glasses
  Future<void> pushScreen(int screenCode) async {
    await Proto.pushScreen(screenCode);
  }

  /// Show EvenAI screen (0x01)
  Future<void> showEvenAIScreen() async {
    await pushScreen(0x01);
  }

  /// Hide EvenAI screen (0x00)
  Future<void> hideEvenAIScreen() async {
    await pushScreen(0x00);
  }

  /// Clear display
  void clearDisplay() {
    _displayTextController.add('');
  }

  /// Convert display parameters to Even Realities format
  static int transferToNewScreen(int type, int status) {
    return (type << 4) | (status & 0x0F);
  }

  /// Dispose resources
  void dispose() {
    _displayTextController.close();
  }
}
