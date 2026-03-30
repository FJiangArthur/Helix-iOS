import 'dart:ui' as ui;

import 'package:flutter/painting.dart';

import '../bmp_widget.dart';
import '../display_constants.dart';
import '../draw_helpers.dart';
import '../enhanced_data_provider.dart';

/// Condensed status bar: time + date + weather + battery + notification count.
/// Designed for 640×28-32 px header zones.
class BmpEnhancedHeaderWidget extends BmpWidget {
  static const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  DateTime _now = DateTime.now();

  @override
  String get id => 'enh_header';

  @override
  String get displayName => 'Enhanced Header';

  @override
  Duration get refreshInterval => const Duration(minutes: 1);

  @override
  Future<void> refresh() async {
    _now = DateTime.now();
    await EnhancedDataProvider.instance.refreshWeather();
    lastRefreshed = _now;
  }

  @override
  void renderToCanvas(ui.Canvas canvas, HudZone zone) {
    final w = zone.width.toDouble();
    final h = zone.height.toDouble();
    final data = EnhancedDataProvider.instance;
    final now = _now;

    // Time
    final hour = now.hour.toString().padLeft(2, '0');
    final minute = now.minute.toString().padLeft(2, '0');
    final timeStr = '$hour:$minute';
    HudDraw.text(canvas, timeStr, const Offset(4, 2),
        fontSize: 18, weight: FontWeight.bold);

    // Date
    final weekday = _weekdays[now.weekday - 1].toUpperCase();
    final month = _months[now.month - 1].toUpperCase();
    final dateStr = '$weekday $month ${now.day}';
    HudDraw.text(canvas, dateStr, const Offset(76, 5), fontSize: 14);

    // Weather (centered area)
    final tempStr = data.weatherTemp != null
        ? '${data.weatherTemp!.round()}°F'
        : '--°';
    HudDraw.text(canvas, tempStr, Offset(w * 0.4, 5), fontSize: 14);

    // Weather icon
    if (data.weatherCode != null) {
      final icon = _iconForCode(data.weatherCode!);
      HudDraw.icon(canvas, Offset(w * 0.4 + 44, 1), icon, 18);
    }

    // Battery (right side)
    final batPct = (data.phoneBattery * 100).round();
    HudDraw.batteryIcon(canvas, Offset(w - 106, 2), 20,
        fillPercent: data.phoneBattery);
    HudDraw.text(canvas, '$batPct%', Offset(w - 82, 5), fontSize: 12);

    // Notification count (far right)
    if (data.notificationCount > 0) {
      final countStr = data.notificationCount > 99
          ? '99+'
          : '${data.notificationCount}';
      HudDraw.icon(canvas, Offset(w - 42, 2), HudIcon.bell, 16);
      HudDraw.text(canvas, countStr, Offset(w - 24, 5), fontSize: 12);
    }

    // Bottom separator
    HudDraw.hLine(canvas, 0, h - 1, w, thickness: 1);
  }

  HudIcon _iconForCode(int code) {
    if (code == 0 || code == 1) return HudIcon.sun;
    if (code >= 2 && code <= 3) return HudIcon.cloud;
    if (code >= 51 && code <= 67) return HudIcon.rain;
    if (code >= 71 && code <= 77) return HudIcon.snow;
    if (code >= 80 && code <= 82) return HudIcon.rain;
    if (code >= 85 && code <= 86) return HudIcon.snow;
    if (code >= 95) return HudIcon.rain;
    return HudIcon.cloud;
  }
}
