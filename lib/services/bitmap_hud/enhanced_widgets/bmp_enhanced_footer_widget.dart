import 'dart:ui' as ui;

import 'package:flutter/painting.dart';

import '../bmp_widget.dart';
import '../display_constants.dart';
import '../draw_helpers.dart';
import '../enhanced_data_provider.dart';

/// Bottom status strip: next event countdown + step count + connection status.
/// Designed for 640×24 px footer zones.
class BmpEnhancedFooterWidget extends BmpWidget {
  @override
  String get id => 'enh_footer';

  @override
  String get displayName => 'Enhanced Footer';

  @override
  Duration get refreshInterval => const Duration(minutes: 1);

  @override
  Future<void> refresh() async {
    await EnhancedDataProvider.instance.refreshCalendar();
    await EnhancedDataProvider.instance.refreshActivity();
    lastRefreshed = DateTime.now();
  }

  @override
  void renderToCanvas(ui.Canvas canvas, HudZone zone) {
    final w = zone.width.toDouble();
    final data = EnhancedDataProvider.instance;

    HudDraw.hLine(canvas, 0, 0, w, thickness: 1);

    String eventText = 'No upcoming events';
    if (data.calendarEvents.isNotEmpty) {
      final next = data.calendarEvents.first;
      final mins = next.minutesUntil();
      if (mins != null && mins > 0) {
        if (mins < 60) {
          eventText = '${next.title} in ${mins}m';
        } else {
          final h = mins ~/ 60;
          final m = mins % 60;
          eventText = '${next.title} in ${h}h${m > 0 ? ' ${m}m' : ''}';
        }
      } else {
        eventText = next.title;
      }
    }
    if (eventText.length > 30) eventText = '${eventText.substring(0, 27)}...';
    HudDraw.icon(canvas, const Offset(2, 3), HudIcon.calendar, 10);
    HudDraw.text(canvas, eventText, const Offset(14, 3), fontSize: 9, maxWidth: w * 0.5);

    HudDraw.text(canvas, '·', Offset(w * 0.52, 2), fontSize: 10);

    if (data.activityAvailable) {
      final stepsStr = _formatNumber(data.steps);
      HudDraw.icon(canvas, Offset(w * 0.56, 3), HudIcon.steps, 10);
      HudDraw.text(canvas, '$stepsStr steps', Offset(w * 0.56 + 12, 3), fontSize: 9);
    }

    if (data.bleConnected) {
      canvas.drawCircle(Offset(w - 8, 8), 3, Paint()
        ..color = const ui.Color(0xFFFFFFFF)..isAntiAlias = false);
    } else {
      canvas.drawCircle(Offset(w - 8, 8), 3, Paint()
        ..color = const ui.Color(0xFFFFFFFF)..style = PaintingStyle.stroke..strokeWidth = 1..isAntiAlias = false);
    }
  }

  String _formatNumber(int n) {
    if (n >= 1000) {
      return '${(n / 1000).toStringAsFixed(1)}k';
    }
    return '$n';
  }
}
