import 'dart:async';
import 'package:flutter/foundation.dart';
import 'proto.dart';
import '../ble_manager.dart';
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

  /// WS-J: minimum display window for the liveListening indicator.
  /// Any transition that leaves liveListening within this window is latched
  /// (deferred). If a new transition back to liveListening arrives during the
  /// latch window, the deferred transition is cancelled entirely — this
  /// prevents the "flash" the orchestration spec calls out where streaming
  /// race conditions briefly clear and re-set the indicator.
  static const Duration liveListeningStableWindow = Duration(milliseconds: 500);
  DateTime? _liveListeningEnteredAt;
  Timer? _deferredLeaveTimer;
  _DeferredTransition? _pendingLeaveTransition;

  /// Stream of text to display on HUD
  Stream<String> get displayTextStream => _displayTextController.stream;
  Stream<HudRouteState> get intentStream => _intentController.stream;
  HudIntent get currentIntent => _currentIntent;
  String get currentDisplayText => _currentDisplayText;

  /// Update HUD with new text
  void updateDisplay(String text) {
    if (!BleManager.get().isConnected) {
      appLogger.w('HudController.updateDisplay: skipped, glasses not connected');
      return;
    }
    _currentDisplayText = text;
    _displayTextController.add(text);
  }

  /// Push screen command to glasses. Returns true if successful.
  Future<bool> pushScreen(int screenCode) async {
    if (!BleManager.get().isConnected) {
      appLogger.w('HudController.pushScreen: skipped, glasses not connected');
      return false;
    }
    return await Proto.pushScreen(screenCode);
  }

  Future<void> transitionTo(
    HudIntent intent, {
    required String source,
    bool pushEvenAiScreen = false,
    bool hideEvenAiScreen = false,
  }) async {
    // WS-J latch: if we're currently showing the liveListening indicator and
    // a non-liveListening transition arrives inside the stable window, defer
    // it. If a re-entry to liveListening arrives during the latch, cancel
    // the pending leave so the indicator never flashes.
    if (intent == HudIntent.liveListening) {
      // Re-entry to liveListening cancels any pending leave — this is the
      // core flash-suppression path.
      _cancelDeferredLeave();
    } else if (_currentIntent == HudIntent.liveListening &&
        _liveListeningEnteredAt != null) {
      final held = DateTime.now().difference(_liveListeningEnteredAt!);
      if (held < liveListeningStableWindow) {
        final remaining = liveListeningStableWindow - held;
        appLogger.d(
          'HudController -> latching leave of liveListening '
          '(wanted=${intent.name}, source=$source, remaining=${remaining.inMilliseconds}ms)',
        );
        // Replace any previously-pending leave — most recent wins.
        _deferredLeaveTimer?.cancel();
        _pendingLeaveTransition = _DeferredTransition(
          intent: intent,
          source: source,
          pushEvenAiScreen: pushEvenAiScreen,
          hideEvenAiScreen: hideEvenAiScreen,
        );
        _deferredLeaveTimer = Timer(remaining, () {
          final pending = _pendingLeaveTransition;
          _pendingLeaveTransition = null;
          _deferredLeaveTimer = null;
          if (pending == null) return;
          // Guard: if during the latch window we ended up back on
          // liveListening (or no longer on liveListening because an explicit
          // non-latched path intervened), skip the deferred transition.
          if (_currentIntent != HudIntent.liveListening) return;
          unawaited(
            transitionTo(
              pending.intent,
              source: '${pending.source}.latched',
              pushEvenAiScreen: pending.pushEvenAiScreen,
              hideEvenAiScreen: pending.hideEvenAiScreen,
            ),
          );
        });
        return;
      }
    }

    final pushesScreen = pushEvenAiScreen || hideEvenAiScreen;
    bool pushSucceeded = true;

    if (hideEvenAiScreen) {
      pushSucceeded = await pushScreen(0x00);
    } else if (pushEvenAiScreen) {
      pushSucceeded = await pushScreen(0x01);
    }

    // Only update intent if no push was needed or the push succeeded
    if (!pushesScreen || pushSucceeded) {
      _currentIntent = intent;
      if (intent == HudIntent.liveListening) {
        _liveListeningEnteredAt = DateTime.now();
      } else {
        _liveListeningEnteredAt = null;
      }
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
    } else {
      appLogger.w(
        'HudController -> pushScreen failed, intent not updated (wanted=${intent.name}, source=$source)',
      );
    }
  }

  void _cancelDeferredLeave() {
    if (_deferredLeaveTimer != null) {
      appLogger.d('HudController -> cancelling deferred leave (re-entry to liveListening)');
    }
    _deferredLeaveTimer?.cancel();
    _deferredLeaveTimer = null;
    _pendingLeaveTransition = null;
  }

  /// WS-J test hook: reset the latch state so unit tests can run in isolation
  /// without leaking state between cases (HudController is a singleton).
  @visibleForTesting
  void resetLiveListeningLatchForTest() {
    _cancelDeferredLeave();
    _liveListeningEnteredAt = null;
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
    _deferredLeaveTimer?.cancel();
    _deferredLeaveTimer = null;
    _pendingLeaveTransition = null;
    _displayTextController.close();
    _intentController.close();
  }
}

class _DeferredTransition {
  const _DeferredTransition({
    required this.intent,
    required this.source,
    required this.pushEvenAiScreen,
    required this.hideEvenAiScreen,
  });

  final HudIntent intent;
  final String source;
  final bool pushEvenAiScreen;
  final bool hideEvenAiScreen;
}
