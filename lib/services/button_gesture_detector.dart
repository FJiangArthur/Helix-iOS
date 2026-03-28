import 'dart:async';

import 'package:flutter_helix/models/glasses_gesture.dart';
import 'package:flutter_helix/services/ble.dart';
import 'package:flutter_helix/utils/app_logger.dart';

enum _GestureState { idle, pressDetected, longPressing, cooldown }

class ButtonGestureDetector {
  ButtonGestureDetector._({
    this.multiTapWindow = const Duration(milliseconds: 300),
    this.longPressThreshold = const Duration(milliseconds: 600),
    this.cooldownDuration = const Duration(milliseconds: 500),
  });

  static ButtonGestureDetector? _instance;
  static ButtonGestureDetector get instance =>
      _instance ??= ButtonGestureDetector._();

  /// Create or replace the singleton with custom timing constants.
  static ButtonGestureDetector configure({
    Duration multiTapWindow = const Duration(milliseconds: 300),
    Duration longPressThreshold = const Duration(milliseconds: 600),
    Duration cooldownDuration = const Duration(milliseconds: 500),
  }) {
    _instance?.dispose();
    _instance = ButtonGestureDetector._(
      multiTapWindow: multiTapWindow,
      longPressThreshold: longPressThreshold,
      cooldownDuration: cooldownDuration,
    );
    return _instance!;
  }

  // Timing constants
  final Duration multiTapWindow;
  final Duration longPressThreshold;
  final Duration cooldownDuration;

  // Stream
  final _gestureController = StreamController<GlassesGesture>.broadcast();
  Stream<GlassesGesture> get gestureStream => _gestureController.stream;

  // State
  _GestureState _state = _GestureState.idle;
  int _tapCount = 0;
  bool _released = false;

  // Timers
  Timer? _multiTapTimer;
  Timer? _longPressTimer;
  Timer? _cooldownTimer;

  // Subscriptions
  StreamSubscription<BleDeviceEvent>? _eventSubscription;
  StreamSubscription<BleConnectionState>? _connectionSubscription;

  /// Subscribe to the raw BLE device event stream and optionally the
  /// connection state stream (to detect disconnects during long press).
  void initialize(
    Stream<BleDeviceEvent> deviceEventStream, {
    Stream<BleConnectionState>? connectionStateStream,
  }) {
    _eventSubscription?.cancel();
    _connectionSubscription?.cancel();

    _eventSubscription = deviceEventStream.listen(_onDeviceEvent);

    if (connectionStateStream != null) {
      _connectionSubscription = connectionStateStream.listen(_onConnectionState);
    }

    appLogger.i('ButtonGestureDetector initialized');
  }

  void dispose() {
    _cancelAllTimers();
    _eventSubscription?.cancel();
    _connectionSubscription?.cancel();
    _eventSubscription = null;
    _connectionSubscription = null;
    _gestureController.close();
    _instance = null;
  }

  // ---------------------------------------------------------------------------
  // Event handling
  // ---------------------------------------------------------------------------

  void _onDeviceEvent(BleDeviceEvent event) {
    if (event.kind == BleDeviceEventKind.evenaiStart) {
      _onPress(event.timestamp);
    } else if (event.kind == BleDeviceEventKind.evenaiRecordOver) {
      _onRelease(event.timestamp);
    }
  }

  void _onConnectionState(BleConnectionState state) {
    if (state == BleConnectionState.disconnected &&
        _state == _GestureState.longPressing) {
      appLogger.w('BLE disconnected during long press — auto-ending');
      _emit(GlassesGestureType.longPressEnd);
      _transitionToIdle();
    }
  }

  // ---------------------------------------------------------------------------
  // State machine
  // ---------------------------------------------------------------------------

  void _onPress(DateTime timestamp) {
    switch (_state) {
      case _GestureState.idle:
        _tapCount = 1;
        _released = false;
        _startMultiTapTimer();
        _startLongPressTimer();
        _state = _GestureState.pressDetected;
        appLogger.d('Gesture: press detected (tap #$_tapCount)');

      case _GestureState.pressDetected:
        _tapCount++;
        _released = false;
        // Reset multi-tap window
        _multiTapTimer?.cancel();
        _startMultiTapTimer();
        // Reset long press timer for this new press
        _longPressTimer?.cancel();
        _startLongPressTimer();
        appLogger.d('Gesture: additional press (tap #$_tapCount)');

        if (_tapCount >= 5) {
          _cancelAllTimers();
          _emit(GlassesGestureType.fivePress);
          _transitionToCooldown();
        }

      case _GestureState.longPressing:
        // Ignore new presses while long pressing
        break;

      case _GestureState.cooldown:
        // Ignore all events during cooldown
        break;
    }
  }

  void _onRelease(DateTime timestamp) {
    switch (_state) {
      case _GestureState.idle:
        // Stale event — ignore
        break;

      case _GestureState.pressDetected:
        _released = true;
        // Cancel long press timer — this was a normal tap
        _longPressTimer?.cancel();
        _longPressTimer = null;
        // Don't emit yet — wait for multi-tap window to expire

      case _GestureState.longPressing:
        _emit(GlassesGestureType.longPressEnd);
        _transitionToIdle();

      case _GestureState.cooldown:
        // Ignore
        break;
    }
  }

  // ---------------------------------------------------------------------------
  // Timer callbacks
  // ---------------------------------------------------------------------------

  void _startMultiTapTimer() {
    _multiTapTimer?.cancel();
    _multiTapTimer = Timer(multiTapWindow, _onMultiTapExpired);
  }

  void _startLongPressTimer() {
    _longPressTimer?.cancel();
    _longPressTimer = Timer(longPressThreshold, _onLongPressExpired);
  }

  void _onMultiTapExpired() {
    if (_state != _GestureState.pressDetected) return;

    _longPressTimer?.cancel();
    _longPressTimer = null;

    final type = switch (_tapCount) {
      1 => GlassesGestureType.singlePress,
      2 => GlassesGestureType.doublePress,
      3 => GlassesGestureType.singlePress,
      4 => GlassesGestureType.doublePress,
      _ => GlassesGestureType.singlePress, // fallback
    };

    _emit(type);
    _transitionToIdle();
  }

  void _onLongPressExpired() {
    if (_state != _GestureState.pressDetected) return;
    if (_released) return; // Already released — not a long press

    _multiTapTimer?.cancel();
    _multiTapTimer = null;

    _emit(GlassesGestureType.longPressStart);
    _state = _GestureState.longPressing;
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  void _emit(GlassesGestureType type) {
    final gesture = GlassesGesture(type: type, timestamp: DateTime.now());
    appLogger.i('Gesture detected: $gesture');
    _gestureController.add(gesture);
  }

  void _transitionToIdle() {
    _cancelAllTimers();
    _tapCount = 0;
    _released = false;
    _state = _GestureState.idle;
  }

  void _transitionToCooldown() {
    _state = _GestureState.cooldown;
    _cooldownTimer?.cancel();
    _cooldownTimer = Timer(cooldownDuration, () {
      _state = _GestureState.idle;
      _tapCount = 0;
      _released = false;
      appLogger.d('Gesture: cooldown ended');
    });
  }

  void _cancelAllTimers() {
    _multiTapTimer?.cancel();
    _multiTapTimer = null;
    _longPressTimer?.cancel();
    _longPressTimer = null;
    _cooldownTimer?.cancel();
    _cooldownTimer = null;
  }
}
