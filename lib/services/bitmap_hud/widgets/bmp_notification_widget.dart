import 'dart:ui' as ui;

import 'package:flutter/painting.dart';

import '../bmp_widget.dart';
import '../display_constants.dart';
import '../draw_helpers.dart';

/// Compact widget showing a bell icon and unread notification count.
/// The count is set externally via [setCount].
class BmpNotificationWidget extends BmpWidget {
  int _count = 0;

  /// Update the unread notification count from outside.
  void setCount(int value) {
    if (_count != value) {
      _count = value;
      isDirty = true;
      return;
    }
    _count = value;
  }

  // BmpWidget -----------------------------------------------------------------

  @override
  String get id => 'bmp_notification';

  @override
  String get displayName => 'Notifications';

  @override
  Duration get refreshInterval => const Duration(minutes: 1);

  @override
  Future<void> refresh() async {
    // Count is pushed from the outside; nothing to poll.
    lastRefreshed = DateTime.now();
  }

  // Rendering -----------------------------------------------------------------

  @override
  void renderToCanvas(ui.Canvas canvas, HudZone zone) {
    const iconSize = 18.0;
    final h = zone.height.toDouble();

    final iconY = (h - iconSize) / 2;
    HudDraw.icon(canvas, Offset(0, iconY), HudIcon.bell, iconSize);

    final countStr = _count > 99 ? '99+' : '$_count';
    HudDraw.text(canvas, countStr, Offset(iconSize + 4, iconY + 1),
        fontSize: 14, weight: FontWeight.bold, maxWidth: zone.width - iconSize - 8);
  }
}
