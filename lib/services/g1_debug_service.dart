import 'dart:async';

import 'package:flutter/services.dart';

import '../ble_manager.dart';
import 'ble.dart';
import 'settings_manager.dart';
import '../utils/app_logger.dart';

/// Service that manages G1 glasses debug logging.
///
/// When enabled, sends the 0x23 0x6C 0x00 command to the glasses to activate
/// firmware debug output. Incoming 0xF4 debug messages are parsed and emitted
/// on [debugMessages]. Each message is also printed to the Dart console so it
/// appears in both Xcode and `flutter logs`.
class G1DebugService {
  G1DebugService._();

  static G1DebugService? _instance;
  static G1DebugService get instance => _instance ??= G1DebugService._();

  static const _channel = MethodChannel('method.bluetooth');

  final _debugController = StreamController<String>.broadcast();
  StreamSubscription<BleReceive>? _bleSubscription;

  /// Whether debug logging is currently active on the glasses.
  bool get isEnabled => SettingsManager.instance.g1DebugLogging;

  /// Stream of parsed debug message strings from the glasses.
  Stream<String> get debugMessages => _debugController.stream;

  /// Accumulated log lines for display in the UI.
  final List<String> logBuffer = [];

  /// Maximum number of log lines to retain.
  static const int maxLogLines = 500;

  /// Start listening for 0xF4 debug messages on the BLE event stream.
  void startListening() {
    _bleSubscription?.cancel();
    _bleSubscription = BleManager.get().eventBleReceive.listen(_onBleReceive);
  }

  /// Stop listening for BLE events.
  void stopListening() {
    _bleSubscription?.cancel();
    _bleSubscription = null;
  }

  void _onBleReceive(BleReceive receive) {
    if (receive.getCmd() != 0xF4) return;
    if (receive.data.length < 2) return;

    // Bytes 1+ are null-terminated ASCII.
    final payload = receive.data.sublist(1);
    // Strip trailing null bytes.
    int end = payload.length;
    for (int i = 0; i < payload.length; i++) {
      if (payload[i] == 0) {
        end = i;
        break;
      }
    }
    final message = String.fromCharCodes(payload.sublist(0, end));
    if (message.isEmpty) return;

    final timestamp =
        DateTime.now().toIso8601String().substring(11, 23); // HH:mm:ss.SSS
    final logLine = '[$timestamp] $message';

    logBuffer.add(logLine);
    if (logBuffer.length > maxLogLines) {
      logBuffer.removeRange(0, logBuffer.length - maxLogLines);
    }

    _debugController.add(logLine);
    appLogger.d('[G1 Debug] $message');
  }

  /// Enable debug logging on the glasses.
  Future<void> enable() async {
    await _channel.invokeMethod('sendDebugControl', {'enable': true});
    await SettingsManager.instance.update((s) => s.g1DebugLogging = true);
    startListening();
    _addSystemMessage('Debug logging enabled');
  }

  /// Disable debug logging on the glasses.
  Future<void> disable() async {
    await _channel.invokeMethod('sendDebugControl', {'enable': false});
    await SettingsManager.instance.update((s) => s.g1DebugLogging = false);
    _addSystemMessage('Debug logging disabled');
  }

  /// Toggle debug logging.
  Future<void> toggle(bool enabled) async {
    if (enabled) {
      await enable();
    } else {
      await disable();
    }
  }

  /// Clear the log buffer.
  void clearLogs() {
    logBuffer.clear();
    _debugController.add(''); // Notify listeners to refresh.
  }

  void _addSystemMessage(String message) {
    final timestamp =
        DateTime.now().toIso8601String().substring(11, 23);
    final logLine = '[$timestamp] --- $message ---';
    logBuffer.add(logLine);
    _debugController.add(logLine);
  }

  /// Clean up resources.
  void dispose() {
    _bleSubscription?.cancel();
    _debugController.close();
  }
}
