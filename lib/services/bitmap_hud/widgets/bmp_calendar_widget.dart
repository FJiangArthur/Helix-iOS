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
    const iconSize = 14.0;
    final w = zone.width.toDouble();

    HudDraw.icon(canvas, Offset.zero, HudIcon.calendar, iconSize);

    const titleX = iconSize + 4.0;
    final maxTextW = w - iconSize - 8;
    final title = _title ?? 'No upcoming events';
    HudDraw.text(canvas, title, const Offset(titleX, 0),
        fontSize: 11, weight: FontWeight.bold, maxWidth: maxTextW);

    final timeStr = _formatTime();
    final locStr = _location != null && _location!.isNotEmpty ? ' · $_location' : '';
    final subtitle = '$timeStr$locStr';
    if (subtitle.isNotEmpty) {
      HudDraw.text(canvas, subtitle, const Offset(titleX, 14),
          fontSize: 9, maxWidth: maxTextW);
    }
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
