import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'hud_widget.dart';

/// Displays the connected glasses battery level on the HUD.
///
/// Note: `getBatteryLevel` is not yet implemented on the native bluetooth
/// channel. The widget will show "BATT: --" until the native side is added.
class BatteryWidget extends HudWidget {
  static const _channel = MethodChannel('method.bluetooth');

  int? _level;

  @override
  String get id => 'battery';
  @override
  String get displayName => 'Battery';
  @override
  IconData get icon => Icons.battery_std;
  @override
  Duration get refreshInterval => const Duration(minutes: 2);
  @override
  int get maxLines => 1;

  @override
  Future<void> refresh() async {
    try {
      final result = await _channel.invokeMethod<int>('getBatteryLevel');
      _level = result; // May be null if unavailable.
    } catch (_) {
      // Keep cached data on failure.
    }
    lastRefreshed = DateTime.now();
  }

  @override
  List<String> renderLines() {
    try {
      if (_level == null) {
        return [HudWidget.truncate('BATT: --')];
      }
      return [HudWidget.truncate('BATT: $_level%')];
    } catch (_) {
      return [HudWidget.truncate('BATT: --')];
    }
  }
}
