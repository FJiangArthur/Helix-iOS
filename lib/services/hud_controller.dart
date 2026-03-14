import 'dart:async';
import 'proto.dart';
import '../utils/app_logger.dart';
import 'hud_intent.dart';

/// Controls HUD display and screen management for G1 glasses
class HudController {
  HudController._();

  static HudController? _instance;
  static HudController get instance => _instance ??= HudController._();

  final StreamController<String> _displayTextController =
      StreamController<String>.broadcast();
  final StreamController<HudRouteState> _intentController =
      StreamController<HudRouteState>.broadcast();
  HudIntent _currentIntent = HudIntent.idle;
  String _currentDisplayText = '';

  /// Stream of text to display on HUD
  Stream<String> get displayTextStream => _displayTextController.stream;
  Stream<HudRouteState> get intentStream => _intentController.stream;
  HudIntent get currentIntent => _currentIntent;
  String get currentDisplayText => _currentDisplayText;

  /// Update HUD with new text
  void updateDisplay(String text) {
    _currentDisplayText = text;
    _displayTextController.add(text);
  }

  /// Push screen command to glasses
  Future<void> pushScreen(int screenCode) async {
    await Proto.pushScreen(screenCode);
  }

  Future<void> transitionTo(
    HudIntent intent, {
    required String source,
    bool pushEvenAiScreen = false,
    bool hideEvenAiScreen = false,
  }) async {
    final pushesScreen = pushEvenAiScreen || hideEvenAiScreen;
    if (hideEvenAiScreen) {
      await pushScreen(0x00);
    } else if (pushEvenAiScreen) {
      await pushScreen(0x01);
    }

    _currentIntent = intent;
    final routeState = HudRouteState(
      intent: intent,
      source: source,
      timestamp: DateTime.now(),
      pushesScreen: pushesScreen,
    );
    _intentController.add(routeState);
    appLogger.d(
      'HudController -> intent=${intent.name}, source=$source, pushesScreen=$pushesScreen',
    );
  }

  Future<void> beginQuickAsk({String source = 'unknown'}) async {
    await transitionTo(HudIntent.quickAsk, source: source);
  }

  Future<void> beginLiveListening({String source = 'unknown'}) async {
    await transitionTo(
      HudIntent.liveListening,
      source: source,
      pushEvenAiScreen: true,
    );
  }

  Future<void> beginTextTransfer({String source = 'unknown'}) async {
    await transitionTo(HudIntent.textTransfer, source: source);
  }

  Future<void> beginNotification({String source = 'unknown'}) async {
    await transitionTo(HudIntent.notification, source: source);
  }

  Future<void> beginDashboard({String source = 'unknown'}) async {
    await transitionTo(HudIntent.dashboard, source: source);
  }

  Future<void> resetToIdle({
    String source = 'unknown',
    bool hideScreen = false,
  }) async {
    await transitionTo(
      HudIntent.idle,
      source: source,
      hideEvenAiScreen: hideScreen,
    );
  }

  /// Show EvenAI screen (0x01)
  Future<void> showEvenAIScreen() async {
    await beginLiveListening(source: 'HudController.showEvenAIScreen');
  }

  /// Hide EvenAI screen (0x00)
  Future<void> hideEvenAIScreen() async {
    await resetToIdle(
      source: 'HudController.hideEvenAIScreen',
      hideScreen: true,
    );
  }

  /// Clear display
  void clearDisplay() {
    _currentDisplayText = '';
    _displayTextController.add('');
  }

  /// Convert display parameters to Even Realities format
  static int transferToNewScreen(int type, int status) {
    return (type << 4) | (status & 0x0F);
  }

  /// Dispose resources
  void dispose() {
    _displayTextController.close();
    _intentController.close();
  }
}
