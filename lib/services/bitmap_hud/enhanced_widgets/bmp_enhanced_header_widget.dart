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

    final hour = now.hour.toString().padLeft(2, '0');
    final minute = now.minute.toString().padLeft(2, '0');
    HudDraw.text(canvas, '$hour:$minute', const Offset(2, 1), fontSize: 12, weight: FontWeight.bold);

    final weekday = _weekdays[now.weekday - 1].toUpperCase();
    final month = _months[now.month - 1].toUpperCase();
    HudDraw.text(canvas, '$weekday $month ${now.day}', const Offset(52, 2), fontSize: 10);

    final tempStr = data.weatherTemp != null ? '${data.weatherTemp!.round()}°F' : '--°';
    HudDraw.text(canvas, tempStr, Offset(w * 0.38, 2), fontSize: 10);

    if (data.weatherCode != null) {
      final icon = _iconForCode(data.weatherCode!);
      HudDraw.icon(canvas, Offset(w * 0.38 + 32, 0), icon, 14);
    }

    final batPct = (data.phoneBattery * 100).round();
    HudDraw.batteryIcon(canvas, Offset(w - 80, 0), 14, fillPercent: data.phoneBattery);
    HudDraw.text(canvas, '$batPct%', Offset(w - 64, 2), fontSize: 10);

    if (data.notificationCount > 0) {
      final countStr = data.notificationCount > 99 ? '99+' : '${data.notificationCount}';
      HudDraw.icon(canvas, Offset(w - 32, 0), HudIcon.bell, 12);
      HudDraw.text(canvas, countStr, Offset(w - 18, 2), fontSize: 10);
    }

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
