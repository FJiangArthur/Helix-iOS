import 'dart:ui' as ui;

import 'package:flutter/painting.dart';

import '../bmp_widget.dart';
import '../display_constants.dart';
import '../draw_helpers.dart';

/// Displays the phone battery level as an icon with fill and percentage text.
/// The level is set externally via [setLevel].
class BmpBatteryWidget extends BmpWidget {
  /// Battery level from 0.0 to 1.0.
  double _level = 1.0;

  /// Update the battery level (0.0–1.0) from outside.
  void setLevel(double value) {
    final normalized = value.clamp(0.0, 1.0).toDouble();
    if ((_level - normalized).abs() > 0.0001) {
      _level = normalized;
      isDirty = true;
      return;
    }
    _level = normalized;
  }

  // BmpWidget -----------------------------------------------------------------

  @override
  String get id => 'bmp_battery';

  @override
  String get displayName => 'Battery';

  @override
  Duration get refreshInterval => const Duration(minutes: 2);

  @override
  Future<void> refresh() async {
    // Level is pushed from the outside; nothing to poll.
    lastRefreshed = DateTime.now();
  }

  // Rendering -----------------------------------------------------------------

  @override
  void renderToCanvas(ui.Canvas canvas, HudZone zone) {
    const iconSize = 18.0;
    final h = zone.height.toDouble();

    final iconY = (h - iconSize) / 2;
    HudDraw.batteryIcon(canvas, Offset(0, iconY), iconSize, fillPercent: _level);

    final pct = (_level * 100).round();
    HudDraw.text(canvas, '$pct%', Offset(iconSize + 4, iconY + 1),
        fontSize: 14, weight: FontWeight.bold, maxWidth: zone.width - iconSize - 8);
  }
}
