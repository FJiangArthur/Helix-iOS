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
    const iconSize = 28.0;
    final h = zone.height.toDouble();

    // Centre vertically within zone (local coords — canvas is pre-translated).
    final iconY = (h - iconSize) / 2;
    HudDraw.icon(canvas, Offset(0, iconY), HudIcon.bell, iconSize);

    // Count text to the right.
    final countStr = _count > 99 ? '99+' : '$_count';
    HudDraw.text(
      canvas, countStr,
      Offset(iconSize + 4, iconY + 2),
      fontSize: 22, weight: FontWeight.bold,
      maxWidth: zone.width - iconSize - 8,
    );
  }
}
