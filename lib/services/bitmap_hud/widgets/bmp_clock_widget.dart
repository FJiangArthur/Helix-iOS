import 'dart:ui' as ui;

import 'package:flutter/painting.dart';

import '../bmp_widget.dart';
import '../display_constants.dart';
import '../draw_helpers.dart';

/// Renders a large clock with date on the bitmap HUD.
///
/// Layout within zone:
///   - Date/weekday line at top (~18pt)
///   - Large time in the center (~60pt bold)
class BmpClockWidget extends BmpWidget {
  static const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  static const _months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  DateTime _now = DateTime.now();

  @override
  String get id => 'bmp_clock';

  @override
  String get displayName => 'Clock';

  @override
  Duration get refreshInterval => const Duration(minutes: 1);

  @override
  Future<void> refresh() async {
    final next = DateTime.now();
    final minuteChanged =
        next.minute != _now.minute ||
        next.hour != _now.hour ||
        next.day != _now.day ||
        next.month != _now.month ||
        next.year != _now.year;
    _now = next;
    if (minuteChanged) {
      isDirty = true;
    }
    lastRefreshed = _now;
  }

  @override
  void renderToCanvas(ui.Canvas canvas, HudZone zone) {
    final now = _now;
    final hour = now.hour.toString().padLeft(2, '0');
    final minute = now.minute.toString().padLeft(2, '0');
    final weekday = _weekdays[now.weekday - 1];
    final month = _months[now.month - 1];
    final dateStr = '$weekday, $month ${now.day}';
    final timeStr = '$hour:$minute';

    final w = zone.width.toDouble();
    final h = zone.height.toDouble();

    // Date line at top
    HudDraw.text(canvas, dateStr, Offset(8, 8), fontSize: 20, maxWidth: w - 16);

    // Large time — centered vertically in remaining space
    final timeSize = HudDraw.measure(
      timeStr,
      fontSize: 64,
      weight: FontWeight.bold,
    );
    final tx = (w - timeSize.width) / 2;
    final ty = 36 + (h - 36 - timeSize.height) / 2;

    HudDraw.text(
      canvas,
      timeStr,
      Offset(tx, ty),
      fontSize: 64,
      weight: FontWeight.bold,
    );
  }
}
