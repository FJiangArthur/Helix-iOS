import 'dart:ui' as ui;

import 'package:flutter/painting.dart';

import '../bmp_widget.dart';
import '../display_constants.dart';
import '../draw_helpers.dart';
import '../enhanced_data_provider.dart';

/// Activity/fitness widget with three progress rings (Move, Exercise, Stand)
/// and numeric values, similar to Apple Watch activity display.
class BmpActivityWidget extends BmpWidget {
  @override
  String get id => 'enh_activity';

  @override
  String get displayName => 'Activity';

  @override
  Duration get refreshInterval => const Duration(minutes: 5);

  @override
  Future<void> refresh() async {
    await EnhancedDataProvider.instance.refreshActivity();
    lastRefreshed = DateTime.now();
  }

  @override
  void renderToCanvas(ui.Canvas canvas, HudZone zone) {
    final w = zone.width.toDouble();
    final h = zone.height.toDouble();
    final data = EnhancedDataProvider.instance;

    HudDraw.icon(canvas, Offset.zero, HudIcon.activity, 10);
    HudDraw.text(canvas, 'ACTIVITY', const Offset(12, 0), fontSize: 9, weight: FontWeight.bold);

    if (!data.activityAvailable) {
      HudDraw.text(canvas, 'Health data unavailable', const Offset(2, 14), fontSize: 10, maxWidth: w - 4);
      return;
    }

    final ringAreaY = 14.0;
    final ringAreaH = h - ringAreaY - 16;
    final ringRadius = (ringAreaH / 2).clamp(8.0, 18.0);
    final ringSpacing = w / 3;
    final ringCenterY = ringAreaY + ringAreaH / 2;

    final moveProgress = (data.steps / data.stepGoal).clamp(0.0, 1.0);
    final moveCx = ringSpacing * 0.5;
    HudDraw.progressRing(canvas, Offset(moveCx, ringCenterY), ringRadius, moveProgress, strokeWidth: 2);

    final exerciseProgress = (data.exerciseMinutes / 30).clamp(0.0, 1.0);
    final exCx = ringSpacing * 1.5;
    HudDraw.progressRing(canvas, Offset(exCx, ringCenterY), ringRadius, exerciseProgress, strokeWidth: 2);

    final standProgress = (data.standHours / 12).clamp(0.0, 1.0);
    final standCx = ringSpacing * 2.5;
    HudDraw.progressRing(canvas, Offset(standCx, ringCenterY), ringRadius, standProgress, strokeWidth: 2);

    final labelY = ringCenterY + ringRadius + 2;
    if (labelY + 10 < h) {
      _drawCenteredLabel(canvas, moveCx, labelY, '${data.steps}', 'MOVE', w / 3 - 4);
      _drawCenteredLabel(canvas, exCx, labelY, '${data.exerciseMinutes}m', 'EX', w / 3 - 4);
      _drawCenteredLabel(canvas, standCx, labelY, '${data.standHours}h', 'STD', w / 3 - 4);
    }
  }

  void _drawCenteredLabel(ui.Canvas canvas, double cx, double y,
      String value, String label, double maxW) {
    final valueSize = HudDraw.measure(value, fontSize: 8, weight: FontWeight.bold);
    HudDraw.text(canvas, value, Offset(cx - valueSize.width / 2, y),
        fontSize: 8, weight: FontWeight.bold, maxWidth: maxW);
  }
}
