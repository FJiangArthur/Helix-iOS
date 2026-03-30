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

    // Title
    HudDraw.icon(canvas, Offset.zero, HudIcon.calendar, 16);
    HudDraw.text(canvas, 'CALENDAR', const Offset(20, 0),
        fontSize: 12, weight: FontWeight.bold);

    if (events.isEmpty) {
      HudDraw.text(canvas, 'No upcoming events', const Offset(4, 22),
          fontSize: 14, maxWidth: w - 8);
      return;
    }

    // Countdown to next event
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
      final countdownSize = HudDraw.measure(countdown, fontSize: 11);
      HudDraw.text(canvas, countdown, Offset(w - countdownSize.width - 2, 0),
          fontSize: 11);

      // Progress bar (assumes 60 min look-ahead)
      final progress = 1.0 - (mins / 60.0).clamp(0.0, 1.0);
      HudDraw.progressBar(
        canvas,
        ui.Rect.fromLTWH(4, 16, w - 8, 6),
        progress,
      );
    }

    // Event list
    var yOffset = 26.0;
    final maxEvents = ((h - yOffset) / 34).floor().clamp(1, 4);

    for (int i = 0; i < events.length && i < maxEvents; i++) {
      final event = events[i];

      // Time (bold)
      final timeStr = event.formatTime();
      HudDraw.text(canvas, timeStr, Offset(4, yOffset),
          fontSize: 13, weight: FontWeight.bold, maxWidth: 80);

      // Title
      var title = event.title;
      if (title.length > 22) title = '${title.substring(0, 19)}...';
      HudDraw.text(canvas, title, Offset(80, yOffset),
          fontSize: 13, maxWidth: w - 84);

      // Location (if present)
      if (event.location != null && event.location!.isNotEmpty) {
        var loc = event.location!;
        if (loc.length > 28) loc = '${loc.substring(0, 25)}...';
        HudDraw.text(canvas, loc, Offset(80, yOffset + 15),
            fontSize: 10, maxWidth: w - 84);
      }

      yOffset += 34;

      // Dashed separator between events
      if (i < events.length - 1 && i < maxEvents - 1) {
        HudDraw.dashedHLine(canvas, 4, yOffset - 4, w - 8,
            dashWidth: 4, gapWidth: 3, thickness: 1);
      }
    }
  }
}
