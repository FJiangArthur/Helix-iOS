import 'dart:ui' as ui;

import 'package:flutter/painting.dart';

import '../bmp_widget.dart';
import '../display_constants.dart';
import '../draw_helpers.dart';
import '../enhanced_data_provider.dart';

/// Multi-event calendar with countdown progress bar to next event.
class BmpEnhancedCalendarWidget extends BmpWidget {
  @override
  String get id => 'enh_calendar';

  @override
  String get displayName => 'Enhanced Calendar';

  @override
  Duration get refreshInterval => const Duration(minutes: 5);

  @override
  Future<void> refresh() async {
    await EnhancedDataProvider.instance.refreshCalendar();
    lastRefreshed = DateTime.now();
  }

  @override
  void renderToCanvas(ui.Canvas canvas, HudZone zone) {
    final w = zone.width.toDouble();
    final h = zone.height.toDouble();
    final events = EnhancedDataProvider.instance.calendarEvents;

    HudDraw.icon(canvas, Offset.zero, HudIcon.calendar, 10);
    HudDraw.text(canvas, 'CALENDAR', const Offset(12, 0), fontSize: 9, weight: FontWeight.bold);

    if (events.isEmpty) {
      HudDraw.text(canvas, 'No upcoming events', const Offset(2, 14), fontSize: 10, maxWidth: w - 4);
      return;
    }

    final next = events.first;
    final mins = next.minutesUntil();
    if (mins != null && mins > 0) {
      String countdown;
      if (mins < 60) {
        countdown = 'IN ${mins}m';
      } else {
        final hr = mins ~/ 60;
        final mn = mins % 60;
        countdown = 'IN ${hr}h${mn > 0 ? ' ${mn}m' : ''}';
      }
      final countdownSize = HudDraw.measure(countdown, fontSize: 9);
      HudDraw.text(canvas, countdown, Offset(w - countdownSize.width - 2, 0), fontSize: 9);
      HudDraw.progressBar(canvas, ui.Rect.fromLTWH(2, 11, w - 4, 4), 1.0 - (mins / 60.0).clamp(0.0, 1.0));
    }

    var yOffset = 18.0;
    final maxEvents = ((h - yOffset) / 18).floor().clamp(1, 4);

    for (int i = 0; i < events.length && i < maxEvents; i++) {
      final event = events[i];
      final timeStr = event.formatTime();
      HudDraw.text(canvas, timeStr, Offset(2, yOffset), fontSize: 9, weight: FontWeight.bold, maxWidth: 48);

      var title = event.title;
      if (title.length > 18) title = '${title.substring(0, 15)}...';
      HudDraw.text(canvas, title, Offset(50, yOffset), fontSize: 9, maxWidth: w - 54);
      yOffset += 18;
    }
  }
}
