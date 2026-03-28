import 'dart:async';

import '../models/glasses_gesture.dart';
import '../utils/app_logger.dart';
import 'button_gesture_detector.dart';
import 'evenai.dart';
import 'settings_manager.dart';
import 'silence_timeout_service.dart';
import 'voice_note_service.dart';

/// Routes high-level glasses gestures to app actions based on current state and settings.
class GestureActionRouter {
  static GestureActionRouter? _instance;
  static GestureActionRouter get instance =>
      _instance ??= GestureActionRouter._();

  GestureActionRouter._();

  StreamSubscription<GlassesGesture>? _gestureSub;
  StreamSubscription<void>? _silenceSub;

  /// Initialize the router by subscribing to gesture and silence streams.
  void initialize() {
    _gestureSub?.cancel();
    _gestureSub =
        ButtonGestureDetector.instance.gestureStream.listen(_handleGesture);

    _silenceSub?.cancel();
    _silenceSub = SilenceTimeoutService.instance.onSilenceTimeout.listen((_) {
      _handleSilenceTimeout();
    });

    appLogger.i('[GestureActionRouter] Initialized');
  }

  void _handleGesture(GlassesGesture gesture) {
    appLogger.i('[GestureActionRouter] Received gesture: ${gesture.type}');

    switch (gesture.type) {
      case GlassesGestureType.singlePress:
        _handleSinglePress();
        break;
      case GlassesGestureType.doublePress:
        _handleDoublePress();
        break;
      case GlassesGestureType.longPressStart:
        _handleLongPressStart();
        break;
      case GlassesGestureType.longPressEnd:
        _handleLongPressEnd();
        break;
      case GlassesGestureType.fivePress:
        _handleFivePress();
        break;
    }
  }

  void _handleSinglePress() {
    // Toggle conversation recording
    if (EvenAI.isRunning) {
      appLogger.i('[GestureActionRouter] Single press -> stop recording');
      EvenAI.get.stopEvenAIByOS();
    } else {
      appLogger.i('[GestureActionRouter] Single press -> start recording');
      EvenAI.get.toStartEvenAIByOS();
      // Start silence timeout monitoring
      final settings = SettingsManager.instance;
      SilenceTimeoutService.instance.start(
        timeout: Duration(minutes: settings.silenceTimeoutMinutes),
      );
    }
  }

  void _handleDoublePress() {
    final settings = SettingsManager.instance;
    switch (settings.doublePressAction) {
      case 'bookmark':
        appLogger.i('[GestureActionRouter] Double press -> bookmark moment');
        // TODO: Implement bookmark - will be wired in Phase 3 (pipeline)
        break;
      case 'force_process':
        appLogger.i('[GestureActionRouter] Double press -> force process');
        if (EvenAI.isRunning) {
          EvenAI.get.stopEvenAIByOS();
          // Pipeline will auto-trigger on stop in Phase 3
        }
        break;
      default:
        appLogger.w(
          '[GestureActionRouter] Unknown double press action: ${settings.doublePressAction}',
        );
    }
  }

  void _handleLongPressStart() {
    final settings = SettingsManager.instance;
    switch (settings.longPressMode) {
      case 'voice_note':
        appLogger.i('[GestureActionRouter] Long press -> start voice note');
        VoiceNoteService.instance.startRecording();
        break;
      case 'walkie_talkie':
        appLogger
            .i('[GestureActionRouter] Long press -> start walkie-talkie');
        // TODO: Wire to walkie-talkie mode
        break;
      default:
        appLogger.i(
          '[GestureActionRouter] Long press -> start voice note (default)',
        );
        VoiceNoteService.instance.startRecording();
        break;
    }
  }

  void _handleLongPressEnd() {
    final settings = SettingsManager.instance;
    switch (settings.longPressMode) {
      case 'voice_note':
        appLogger.i('[GestureActionRouter] Long press end -> stop voice note');
        VoiceNoteService.instance.stopRecording();
        break;
      case 'walkie_talkie':
        appLogger
            .i('[GestureActionRouter] Long press end -> stop walkie-talkie');
        // TODO: Wire to walkie-talkie mode
        break;
      default:
        appLogger.i(
          '[GestureActionRouter] Long press end -> stop voice note (default)',
        );
        VoiceNoteService.instance.stopRecording();
        break;
    }
  }

  void _handleFivePress() {
    appLogger.i('[GestureActionRouter] Five press -> unpair device');
    // TODO: Implement unpair flow - disconnect BLE + clear paired device
    // For now, just stop everything and log
    if (EvenAI.isRunning) {
      EvenAI.get.stopEvenAIByOS();
    }
  }

  void _handleSilenceTimeout() {
    appLogger
        .i('[GestureActionRouter] Silence timeout -> auto-stopping recording');
    if (EvenAI.isRunning) {
      EvenAI.get.stopEvenAIByOS();
    }
  }

  void dispose() {
    _gestureSub?.cancel();
    _silenceSub?.cancel();
  }
}
