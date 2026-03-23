import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'hud_widget.dart';

/// Displays the next upcoming reminder on the HUD.
class RemindersWidget extends HudWidget {
  static const _channel = MethodChannel('method.eventkit');

  Map<String, dynamic>? _cached;

  @override
  String get id => 'reminders';
  @override
  String get displayName => 'Reminders';
  @override
  IconData get icon => Icons.notifications_active;
  @override
  Duration get refreshInterval => const Duration(minutes: 5);
  @override
  int get maxLines => 2;

  @override
  Future<void> refresh() async {
    try {
      final result = await _channel.invokeMethod<List>('getUpcomingReminders');
      if (result != null && result.isNotEmpty) {
        _cached = Map<String, dynamic>.from(result.first as Map);
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
        return [HudWidget.truncate('No reminders')];
      }
      final title = _cached!['title'] as String? ?? '';
      final dueDate = _cached!['dueDate'] as String? ?? '';

      final line1 = HudWidget.truncate('DUE: $title');
      final line2 = HudWidget.truncate(_formatDue(dueDate));
      return [line1, if (line2.isNotEmpty) line2];
    } catch (_) {
      return [HudWidget.truncate('No reminders')];
    }
  }

  String _formatDue(String isoDate) {
    try {
      final dt = DateTime.parse(isoDate).toLocal();
      final now = DateTime.now();
      final hour = dt.hour;
      final minute = dt.minute.toString().padLeft(2, '0');
      final amPm = hour >= 12 ? 'PM' : 'AM';
      final h12 = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
      final time = '$h12:$minute $amPm';

      final today = DateTime(now.year, now.month, now.day);
      final dueDay = DateTime(dt.year, dt.month, dt.day);
      final diff = dueDay.difference(today).inDays;

      if (diff == 0) return 'Today $time';
      if (diff == 1) return 'Tomorrow $time';
      return '${dt.month}/${dt.day} $time';
    } catch (_) {
      return '';
    }
  }
}
