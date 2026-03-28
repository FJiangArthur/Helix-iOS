import 'dart:async';
import 'dart:typed_data';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_helix/models/glasses_gesture.dart';
import 'package:flutter_helix/services/ble.dart';
import 'package:flutter_helix/services/button_gesture_detector.dart';
import 'package:flutter_test/flutter_test.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Short timers so tests run fast.
/// Note: multiTap must be > longPress for long-press detection to work,
/// because _onMultiTapExpired cancels the long-press timer when it fires.
const _multiTap = Duration(milliseconds: 50);
const _longPress = Duration(milliseconds: 200);
const _cooldown = Duration(milliseconds: 50);

/// Timers for long-press tests: longPress threshold must be less than
/// multiTap window, otherwise multiTap fires first and cancels the
/// long-press timer.
const _multiTapLong = Duration(milliseconds: 300);
const _longPressShort = Duration(milliseconds: 100);
const _cooldownLong = Duration(milliseconds: 50);

BleDeviceEvent _press() => BleDeviceEvent(
      kind: BleDeviceEventKind.evenaiStart,
      notifyIndex: 0,
      side: 'L',
      data: Uint8List(0),
      timestamp: DateTime.now(),
      label: 'test_press',
    );

BleDeviceEvent _release() => BleDeviceEvent(
      kind: BleDeviceEventKind.evenaiRecordOver,
      notifyIndex: 0,
      side: 'L',
      data: Uint8List(0),
      timestamp: DateTime.now(),
      label: 'test_release',
    );

typedef _TestEnv = ({
  ButtonGestureDetector detector,
  StreamController<BleDeviceEvent> events,
  StreamController<BleConnectionState> connection,
});

/// Creates a detector, event stream, and connection stream all inside the
/// current zone so that [fakeAsync] can control timers and microtasks.
_TestEnv _createDetector({
  Duration multiTapWindow = _multiTap,
  Duration longPressThreshold = _longPress,
  Duration cooldownDuration = _cooldown,
}) {
  final events = StreamController<BleDeviceEvent>.broadcast();
  final connection = StreamController<BleConnectionState>.broadcast();
  final detector = ButtonGestureDetector.configure(
    multiTapWindow: multiTapWindow,
    longPressThreshold: longPressThreshold,
    cooldownDuration: cooldownDuration,
  );
  detector.initialize(
    events.stream,
    connectionStateStream: connection.stream,
  );
  return (detector: detector, events: events, connection: connection);
}

void _disposeEnv(_TestEnv env) {
  env.detector.dispose();
  env.events.close();
  env.connection.close();
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  // -------------------------------------------------------------------------
  // D1 [P0]: Single press -> emits singlePress
  // -------------------------------------------------------------------------
  test('D1 [P0]: single press emits singlePress', () {
    fakeAsync((async) {
      final env = _createDetector();
      final gestures = <GlassesGesture>[];
      env.detector.gestureStream.listen(gestures.add);

      // Press then release.
      env.events.add(_press());
      async.elapse(const Duration(milliseconds: 10));
      env.events.add(_release());

      // Wait for the multiTap window to expire so the gesture is emitted.
      async.elapse(_multiTap + const Duration(milliseconds: 10));

      expect(gestures, hasLength(1));
      expect(gestures.first.type, GlassesGestureType.singlePress);

      _disposeEnv(env);
    });
  });

  // -------------------------------------------------------------------------
  // D2 [P0]: Double press -> emits doublePress
  // -------------------------------------------------------------------------
  test('D2 [P0]: double press emits doublePress', () {
    fakeAsync((async) {
      final env = _createDetector();
      final gestures = <GlassesGesture>[];
      env.detector.gestureStream.listen(gestures.add);

      // First press/release cycle.
      env.events.add(_press());
      async.elapse(const Duration(milliseconds: 5));
      env.events.add(_release());
      async.elapse(const Duration(milliseconds: 10));

      // Second press/release cycle within the multiTap window.
      env.events.add(_press());
      async.elapse(const Duration(milliseconds: 5));
      env.events.add(_release());

      // Wait for multiTap window to expire.
      async.elapse(_multiTap + const Duration(milliseconds: 10));

      expect(gestures, hasLength(1));
      expect(gestures.first.type, GlassesGestureType.doublePress);

      _disposeEnv(env);
    });
  });

  // -------------------------------------------------------------------------
  // D3 [P1]: Long press -> longPressStart then longPressEnd
  // -------------------------------------------------------------------------
  test('D3 [P1]: long press emits longPressStart then longPressEnd', () {
    fakeAsync((async) {
      // Use timers where longPress < multiTap so the long-press timer fires
      // before the multiTap timer cancels it.
      final env = _createDetector(
        multiTapWindow: _multiTapLong,
        longPressThreshold: _longPressShort,
        cooldownDuration: _cooldownLong,
      );
      final gestures = <GlassesGesture>[];
      env.detector.gestureStream.listen(gestures.add);

      // Press and do NOT release.
      env.events.add(_press());

      // Wait for the long press threshold to fire.
      async.elapse(_longPressShort + const Duration(milliseconds: 10));

      expect(gestures, hasLength(1));
      expect(gestures.first.type, GlassesGestureType.longPressStart);

      // Now release.
      env.events.add(_release());
      async.elapse(const Duration(milliseconds: 10));

      expect(gestures, hasLength(2));
      expect(gestures[1].type, GlassesGestureType.longPressEnd);

      _disposeEnv(env);
    });
  });

  // -------------------------------------------------------------------------
  // D_extra: Five presses -> emits fivePress
  // -------------------------------------------------------------------------
  test('D_extra: five rapid presses emits fivePress', () {
    fakeAsync((async) {
      final env = _createDetector();
      final gestures = <GlassesGesture>[];
      env.detector.gestureStream.listen(gestures.add);

      for (var i = 0; i < 5; i++) {
        env.events.add(_press());
        async.elapse(const Duration(milliseconds: 5));
        env.events.add(_release());
        async.elapse(const Duration(milliseconds: 5));
      }

      // fivePress is emitted immediately on the 5th press, no timer needed.
      expect(gestures, hasLength(1));
      expect(gestures.first.type, GlassesGestureType.fivePress);

      _disposeEnv(env);
    });
  });

  // -------------------------------------------------------------------------
  // D4 [P2]: Cooldown prevents rapid re-trigger
  // -------------------------------------------------------------------------
  test('D4 [P2]: cooldown prevents new gestures during cooldown period', () {
    fakeAsync((async) {
      final env = _createDetector();
      final gestures = <GlassesGesture>[];
      env.detector.gestureStream.listen(gestures.add);

      // Trigger a fivePress which transitions to cooldown.
      for (var i = 0; i < 5; i++) {
        env.events.add(_press());
        async.elapse(const Duration(milliseconds: 5));
        env.events.add(_release());
        async.elapse(const Duration(milliseconds: 5));
      }
      expect(gestures, hasLength(1));
      expect(gestures.first.type, GlassesGestureType.fivePress);

      // Immediately attempt another press during cooldown — should be ignored.
      env.events.add(_press());
      async.elapse(const Duration(milliseconds: 5));
      env.events.add(_release());
      async.elapse(_multiTap + const Duration(milliseconds: 10));

      // Still only the original fivePress.
      expect(gestures, hasLength(1));

      // After cooldown expires, a new press should work.
      async.elapse(_cooldown);
      env.events.add(_press());
      async.elapse(const Duration(milliseconds: 5));
      env.events.add(_release());
      async.elapse(_multiTap + const Duration(milliseconds: 10));

      expect(gestures, hasLength(2));
      expect(gestures[1].type, GlassesGestureType.singlePress);

      _disposeEnv(env);
    });
  });

  // -------------------------------------------------------------------------
  // D_disconnect: BLE disconnect during long press -> auto-ends
  // -------------------------------------------------------------------------
  test('D_disconnect: BLE disconnect during long press emits longPressEnd',
      () {
    fakeAsync((async) {
      final env = _createDetector(
        multiTapWindow: _multiTapLong,
        longPressThreshold: _longPressShort,
        cooldownDuration: _cooldownLong,
      );
      final gestures = <GlassesGesture>[];
      env.detector.gestureStream.listen(gestures.add);

      // Start a long press.
      env.events.add(_press());
      async.elapse(_longPressShort + const Duration(milliseconds: 10));

      expect(gestures, hasLength(1));
      expect(gestures.first.type, GlassesGestureType.longPressStart);

      // Simulate BLE disconnect while still long pressing.
      env.connection.add(BleConnectionState.disconnected);
      async.elapse(const Duration(milliseconds: 10));

      expect(gestures, hasLength(2));
      expect(gestures[1].type, GlassesGestureType.longPressEnd);

      _disposeEnv(env);
    });
  });

  // -------------------------------------------------------------------------
  // Edge: release without press is ignored
  // -------------------------------------------------------------------------
  test('stale release event in idle state is ignored', () {
    fakeAsync((async) {
      final env = _createDetector();
      final gestures = <GlassesGesture>[];
      env.detector.gestureStream.listen(gestures.add);

      env.events.add(_release());
      async.elapse(_multiTap + const Duration(milliseconds: 50));

      expect(gestures, isEmpty);

      _disposeEnv(env);
    });
  });

  // -------------------------------------------------------------------------
  // Edge: gesture is not emitted until multiTap window expires
  // -------------------------------------------------------------------------
  test('gesture is not emitted until multiTap window expires', () {
    fakeAsync((async) {
      final env = _createDetector();
      final gestures = <GlassesGesture>[];
      env.detector.gestureStream.listen(gestures.add);

      env.events.add(_press());
      async.elapse(const Duration(milliseconds: 5));
      env.events.add(_release());

      // Before the multiTap window: no gesture yet.
      async.elapse(const Duration(milliseconds: 10));
      expect(gestures, isEmpty);

      // After the multiTap window: gesture emitted.
      async.elapse(_multiTap);
      expect(gestures, hasLength(1));
      expect(gestures.first.type, GlassesGestureType.singlePress);

      _disposeEnv(env);
    });
  });

  // -------------------------------------------------------------------------
  // BUG-003: Long-press is unreachable with production default timers
  // -------------------------------------------------------------------------
  test('BUG-003: production defaults (multiTap=300ms, longPress=600ms) — long press never fires', () {
    fakeAsync((async) {
      // Use the ACTUAL production default timings
      final env = _createDetector(
        multiTapWindow: const Duration(milliseconds: 300),
        longPressThreshold: const Duration(milliseconds: 600),
        cooldownDuration: const Duration(milliseconds: 500),
      );
      final gestures = <GlassesGesture>[];
      env.detector.gestureStream.listen(gestures.add);

      // Press and hold — don't release
      env.events.add(_press());

      // At 300ms the multiTap timer fires, which cancels the longPress timer
      // and emits singlePress instead. Long press at 600ms never happens.
      async.elapse(const Duration(milliseconds: 700));

      // We get singlePress, NOT longPressStart — this is the bug.
      expect(gestures, hasLength(1));
      expect(gestures.first.type, GlassesGestureType.singlePress);

      // longPressStart was never emitted
      expect(
        gestures.where((g) => g.type == GlassesGestureType.longPressStart),
        isEmpty,
      );

      _disposeEnv(env);
    });
  });
}
