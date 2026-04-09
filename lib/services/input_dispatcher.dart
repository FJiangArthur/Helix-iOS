// input_dispatcher.dart
//
// WS-F: Runtime listener that subscribes to the native
// `event.input_inspector` stream, canonicalises incoming events into
// signature strings, compares them against the bound ring-remote signature
// stored in [SettingsManager.ringBindingSignature], and invokes
// `ConversationEngine.handleQAButtonPressed()` on a match.
//
// See `.planning/orchestration/reports/WS-F-investigation.md` §4 and §5 for
// the full design. Debounce rules (§5):
//
//   1. Primary debounce: 500ms from last successful dispatch
//   2. Phase filter: only `pressEvent` `phase == "began"` participates
//   3. Volume coalescing: `volumeChange` within 50ms of `mediaCommand`
//      or `keyCommand` is dropped as a duplicate edge
//   4. Hold suppression: same signature 3+ times within 150ms
//      -> keep first edge only
//   5. Session guard: dispatch even if engine is inactive; the engine
//      handles the inactive case. Tagged for tests.

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../utils/app_logger.dart';
import 'conversation_engine.dart';
import 'settings_manager.dart';

/// Signature canonicaliser. Pure function, exposed for tests.
String? canonicalSignatureFromEvent(Map<Object?, Object?> event) {
  final channel = event['channel'] as String?;
  if (channel == null) return null;
  switch (channel) {
    case 'keyCommand':
      final input = (event['input'] as String?) ?? '';
      final mods = event['modifierFlags'];
      final modsInt = mods is num ? mods.toInt() : 0;
      return 'keyCommand:$input:$modsInt';
    case 'pressEvent':
      final phase = event['phase'] as String? ?? '';
      if (phase != 'began') return null;
      final code = event['keyCode'];
      final codeInt = code is num ? code.toInt() : 0;
      return 'pressEvent:$codeInt';
    case 'mediaCommand':
      final cmd = (event['command'] as String?) ?? '';
      return 'mediaCommand:$cmd';
    case 'volumeChange':
      final dir = (event['direction'] as String?) ?? 'same';
      if (dir == 'same') return null;
      return 'volumeChange:$dir';
  }
  return null;
}

class InputDispatcher {
  InputDispatcher._({
    MethodChannel? methodChannel,
    EventChannel? eventChannel,
    Future<void> Function()? onDispatch,
  })  : _method = methodChannel ??
            const MethodChannel('method.input_inspector'),
        _events = eventChannel ?? const EventChannel('event.input_inspector'),
        _onDispatch = onDispatch;

  static final InputDispatcher instance = InputDispatcher._();

  /// Build a dispatcher for unit tests with injectable plumbing.
  @visibleForTesting
  static InputDispatcher forTesting({
    required MethodChannel methodChannel,
    required EventChannel eventChannel,
    required Future<void> Function() onDispatch,
  }) {
    return InputDispatcher._(
      methodChannel: methodChannel,
      eventChannel: eventChannel,
      onDispatch: onDispatch,
    );
  }

  final MethodChannel _method;
  final EventChannel _events;
  final Future<void> Function()? _onDispatch;

  StreamSubscription<dynamic>? _sub;
  StreamSubscription<SettingsManager>? _settingsSub;
  bool _started = false;

  // Debounce state
  static const Duration kPrimaryDebounce = Duration(milliseconds: 500);
  static const Duration kVolumeCoalesceWindow = Duration(milliseconds: 50);
  static const Duration kHoldWindow = Duration(milliseconds: 150);
  static const int kHoldThreshold = 3;

  DateTime? _lastDispatchAt;
  DateTime? _lastNonVolumeAt;
  DateTime? _lastSameSignatureAt;
  String? _lastSignatureSeen;
  int _lastSignatureCount = 0;

  // Test observability
  int debouncedCount = 0;
  int dispatchedCount = 0;
  int coalescedVolumeCount = 0;
  int holdSuppressedCount = 0;

  String? _boundSignature;

  Future<void> start() async {
    if (_started) return;
    _started = true;
    _boundSignature = SettingsManager.instance.ringBindingSignature;
    _settingsSub = SettingsManager.instance.onSettingsChanged.listen((s) {
      _boundSignature = s.ringBindingSignature;
    });
    try {
      await _method.invokeMethod<void>('startBackgroundListening');
    } catch (e) {
      appLogger.w('[InputDispatcher] startBackgroundListening failed: $e');
    }
    _sub = _events.receiveBroadcastStream().listen(
      _handleEvent,
      onError: (Object e) {
        appLogger.w('[InputDispatcher] event stream error: $e');
      },
    );
    appLogger.i('[InputDispatcher] started (bound=$_boundSignature)');
  }

  Future<void> stop() async {
    if (!_started) return;
    _started = false;
    await _sub?.cancel();
    _sub = null;
    await _settingsSub?.cancel();
    _settingsSub = null;
    try {
      await _method.invokeMethod<void>('stopBackgroundListening');
    } catch (_) {}
  }

  Future<void> dispose() async {
    await stop();
  }

  /// Entry point exposed for tests — pumps a raw event through the pipeline.
  @visibleForTesting
  Future<void> debugInject(Map<Object?, Object?> event) async {
    await _handleEvent(event);
  }

  /// Update the bound signature directly without hitting SettingsManager
  /// — for tests only.
  @visibleForTesting
  void debugSetBinding(String? signature) {
    _boundSignature = signature;
  }

  Future<void> _handleEvent(dynamic rawEvent) async {
    if (rawEvent is! Map) return;
    final event = rawEvent.cast<Object?, Object?>();
    final signature = canonicalSignatureFromEvent(event);
    if (signature == null) return;

    final bound = _boundSignature;
    if (bound == null || bound.isEmpty) return;
    if (!SettingsManager.instance.ringBindingEnabled) return;

    final now = DateTime.now();
    final channel = event['channel'] as String? ?? '';

    // Rule 3: volume coalescing — volume edge within 50ms of an earlier
    // keyCommand/mediaCommand is treated as a duplicate of the prior event.
    if (channel == 'volumeChange' && _lastNonVolumeAt != null) {
      if (now.difference(_lastNonVolumeAt!) <= kVolumeCoalesceWindow) {
        coalescedVolumeCount++;
        return;
      }
    }
    if (channel == 'keyCommand' || channel == 'mediaCommand') {
      _lastNonVolumeAt = now;
    }

    // Does this event even match the binding?
    if (signature != bound) return;

    // Rule 4: hold suppression — N same-signature events within 150ms keep
    // the first edge only.
    if (_lastSignatureSeen == signature &&
        _lastSameSignatureAt != null &&
        now.difference(_lastSameSignatureAt!) <= kHoldWindow) {
      _lastSignatureCount++;
      if (_lastSignatureCount >= kHoldThreshold) {
        holdSuppressedCount++;
        _lastSameSignatureAt = now;
        return;
      }
    } else {
      _lastSignatureCount = 1;
    }
    _lastSignatureSeen = signature;
    _lastSameSignatureAt = now;

    // Rule 1: primary debounce.
    if (_lastDispatchAt != null &&
        now.difference(_lastDispatchAt!) < kPrimaryDebounce) {
      debouncedCount++;
      return;
    }

    _lastDispatchAt = now;
    dispatchedCount++;
    appLogger.i('[InputDispatcher] dispatch sig=$signature');
    try {
      if (_onDispatch != null) {
        await _onDispatch!();
      } else {
        await ConversationEngine.instance.handleQAButtonPressed();
      }
    } catch (e, st) {
      appLogger.e('[InputDispatcher] dispatch failed', error: e, stackTrace: st);
    }
  }
}
