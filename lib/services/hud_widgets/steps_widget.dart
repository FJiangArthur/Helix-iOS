import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'hud_widget.dart';

/// Displays today's step count from HealthKit on the HUD.
class StepsWidget extends HudWidget {
  static const _channel = MethodChannel('method.healthkit');

  int? _steps;

  @override
  String get id => 'steps';
  @override
  String get displayName => 'Steps';
  @override
  IconData get icon => Icons.directions_walk;
  @override
  Duration get refreshInterval => const Duration(minutes: 10);
  @override
  int get maxLines => 1;

  @override
  Future<void> refresh() async {
    try {
      final result = await _channel.invokeMethod<int>('getTodayStepCount');
      if (result != null) {
        _steps = result;
      }
    } catch (_) {
      // Keep cached data on failure.
    }
    lastRefreshed = DateTime.now();
  }

  @override
  List<String> renderLines() {
    try {
      if (_steps == null) {
        return [HudWidget.truncate('STEPS: --')];
      }
      return [HudWidget.truncate('STEPS: ${_formatNumber(_steps!)}')];
    } catch (_) {
      return [HudWidget.truncate('STEPS: --')];
    }
  }

  /// Formats an integer with comma separators (e.g. 7234 -> "7,234").
  static String _formatNumber(int n) {
    final s = n.toString();
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
      buf.write(s[i]);
    }
    return buf.toString();
  }
}
