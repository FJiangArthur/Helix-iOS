import 'dart:ui' as ui;

import 'package:flutter/services.dart';

import '../../../utils/app_logger.dart';
import '../bmp_widget.dart';
import '../display_constants.dart';
import '../draw_helpers.dart';

/// Shows the next calendar event fetched via EventKit platform channel.
class BmpCalendarWidget extends BmpWidget {
  static const _channel = MethodChannel('method.eventkit');

  // Cached event data ---------------------------------------------------------
  String? _title;
  DateTime? _startDate;
  String? _location;
  bool _isAllDay = false;

  // BmpWidget -----------------------------------------------------------------

  @override
  String get id => 'bmp_calendar';

  @override
  String get displayName => 'Calendar';

  @override
  Duration get refreshInterval => const Duration(minutes: 5);

  @override
  Future<void> refresh() async {
    try {
      final result = await _channel.invokeMethod<Map>('getNextCalendarEvent');
      if (result != null) {
        _title = result['title'] as String?;
        _location = result['location'] as String?;
        _isAllDay = result['isAllDay'] as bool? ?? false;
        final dateStr = result['startDate'] as String?;
        if (dateStr != null) {
          _startDate = DateTime.tryParse(dateStr);
        }
      }
    } on MissingPluginException {
      appLogger.e('BmpCalendar: EventKit channel not registered');
    } on PlatformException catch (e) {
      appLogger.w('BmpCalendar: platform error: ${e.code} ${e.message}');
    } catch (e) {
      appLogger.w('BmpCalendar: refresh failed: $e');
    }
    lastRefreshed = DateTime.now();
  }

  // Rendering -----------------------------------------------------------------

  @override
  void renderToCanvas(ui.Canvas canvas, HudZone zone) {
    const iconSize = 28.0;
    final w = zone.width.toDouble();
    final h = zone.height.toDouble();

    // Calendar icon top-left (local coords — canvas is pre-translated).
    HudDraw.icon(canvas, Offset.zero, HudIcon.calendar, iconSize);

    // Title to the right of icon, truncated.
    const titleX = iconSize + 6.0;
    final maxTextW = w - iconSize - 10;
    final title = _title ?? 'No upcoming events';
    HudDraw.text(
      canvas, title, const Offset(titleX, 2),
      fontSize: 18, weight: FontWeight.bold, maxWidth: maxTextW,
    );

    // Time + location on second line.
    final timeStr = _formatTime();
    final locStr = _location != null && _location!.isNotEmpty
        ? ' · $_location' : '';
    final subtitle = '$timeStr$locStr';
    if (subtitle.isNotEmpty) {
      HudDraw.text(
        canvas, subtitle, const Offset(titleX, 24),
        fontSize: 14, maxWidth: maxTextW,
      );
    }

    // Dashed separator at bottom.
    HudDraw.dashedHLine(canvas, 0, h - 2, w);
  }

  // Helpers -------------------------------------------------------------------

  String _formatTime() {
    if (_startDate == null) return '';
    if (_isAllDay) return 'All day';
    final h = _startDate!.hour;
    final m = _startDate!.minute.toString().padLeft(2, '0');
    final period = h >= 12 ? 'PM' : 'AM';
    final h12 = h == 0 ? 12 : (h > 12 ? h - 12 : h);
    return '$h12:$m $period';
  }
}
