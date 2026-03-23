import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'hud_widget.dart';

/// Displays the next calendar event on the HUD.
class CalendarWidget extends HudWidget {
  static const _channel = MethodChannel('method.eventkit');

  Map<String, dynamic>? _cached;

  @override
  String get id => 'calendar';
  @override
  String get displayName => 'Calendar';
  @override
  IconData get icon => Icons.calendar_today;
  @override
  Duration get refreshInterval => const Duration(minutes: 5);
  @override
  int get maxLines => 2;

  @override
  Future<void> refresh() async {
    try {
      final result = await _channel.invokeMethod<Map>('getNextCalendarEvent');
      if (result != null) {
        _cached = Map<String, dynamic>.from(result);
      } else {
        _cached = null;
      }
    } catch (_) {
      // Keep cached data on failure.
    }
    lastRefreshed = DateTime.now();
  }

  @override
  List<String> renderLines() {
    try {
      if (_cached == null) {
        return [HudWidget.truncate('No upcoming events')];
      }
      final title = _cached!['title'] as String? ?? '';
      final startDate = _cached!['startDate'] as String? ?? '';
      final location = _cached!['location'] as String? ?? '';
      final isAllDay = _cached!['isAllDay'] as bool? ?? false;

      final timePart = isAllDay ? 'All Day' : _formatTime(startDate);
      final line1 = HudWidget.truncate('NEXT: $title');
      final line2Parts = <String>[if (timePart.isNotEmpty) timePart, if (location.isNotEmpty) location];
      final line2 = HudWidget.truncate(line2Parts.join('  '));
      return [line1, if (line2.isNotEmpty) line2];
    } catch (_) {
      return [HudWidget.truncate('No upcoming events')];
    }
  }

  String _formatTime(String isoDate) {
    try {
      final dt = DateTime.parse(isoDate).toLocal();
      final hour = dt.hour;
      final minute = dt.minute.toString().padLeft(2, '0');
      final amPm = hour >= 12 ? 'PM' : 'AM';
      final h12 = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
      return '$h12:$minute $amPm';
    } catch (_) {
      return '';
    }
  }
}
