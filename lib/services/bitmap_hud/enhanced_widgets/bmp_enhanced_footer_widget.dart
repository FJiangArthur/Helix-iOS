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

    // Top separator
    HudDraw.hLine(canvas, 0, 0, w, thickness: 1);

    // Next event countdown (left side)
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
    // Truncate to fit left half
    if (eventText.length > 30) {
      eventText = '${eventText.substring(0, 27)}...';
    }
    HudDraw.icon(canvas, const Offset(4, 4), HudIcon.calendar, 14);
    HudDraw.text(canvas, eventText, const Offset(22, 6),
        fontSize: 11, maxWidth: w * 0.5);

    // Separator dot
    HudDraw.text(canvas, '·', Offset(w * 0.52, 4), fontSize: 14);

    // Step count (right side)
    if (data.activityAvailable) {
      final stepsStr = _formatNumber(data.steps);
      HudDraw.icon(canvas, Offset(w * 0.56, 4), HudIcon.steps, 14);
      HudDraw.text(canvas, '$stepsStr steps', Offset(w * 0.56 + 18, 6),
          fontSize: 11);
    }

    // BLE connection indicator (far right)
    if (data.bleConnected) {
      canvas.drawCircle(Offset(w - 10, 12), 4, Paint()
        ..color = const ui.Color(0xFFFFFFFF)
        ..isAntiAlias = false);
    } else {
      canvas.drawCircle(Offset(w - 10, 12), 4, Paint()
        ..color = const ui.Color(0xFFFFFFFF)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..isAntiAlias = false);
    }
  }

  String _formatNumber(int n) {
    if (n >= 1000) {
      return '${(n / 1000).toStringAsFixed(1)}k';
    }
    return '$n';
  }
}
