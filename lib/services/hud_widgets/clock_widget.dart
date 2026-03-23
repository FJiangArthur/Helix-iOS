import 'package:flutter/material.dart';
import 'hud_widget.dart';

/// Displays current time and date on the HUD.
class ClockWidget extends HudWidget {
  static const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  @override
  String get id => 'clock';
  @override
  String get displayName => 'Clock';
  @override
  IconData get icon => Icons.access_time;
  @override
  Duration get refreshInterval => const Duration(minutes: 1);
  @override
  int get maxLines => 2;

  @override
  Future<void> refresh() async {
    lastRefreshed = DateTime.now();
  }

  @override
  List<String> renderLines() {
    final now = DateTime.now();
    final hour = now.hour.toString().padLeft(2, '0');
    final minute = now.minute.toString().padLeft(2, '0');
    final weekday = _weekdays[now.weekday - 1];
    final month = _months[now.month - 1];
    return [
      '$hour:$minute',
      '$weekday $month ${now.day}',
    ];
  }
}
