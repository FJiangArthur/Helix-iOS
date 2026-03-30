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

    // Title
    HudDraw.icon(canvas, Offset.zero, HudIcon.activity, 16);
    HudDraw.text(canvas, 'ACTIVITY', const Offset(20, 0),
        fontSize: 12, weight: FontWeight.bold);

    // Show unavailable state when HealthKit is not accessible
    if (!data.activityAvailable) {
      HudDraw.text(canvas, 'Health data unavailable', const Offset(4, 24),
          fontSize: 13, maxWidth: w - 8);
      HudDraw.text(canvas, 'Enable in Settings > Health', const Offset(4, 42),
          fontSize: 11, maxWidth: w - 8);
      return;
    }

    // Guard: zone too short for rings
    if (h < 100) {
      HudDraw.text(canvas, '${data.steps} steps', const Offset(4, 22),
          fontSize: 14, weight: FontWeight.bold, maxWidth: w - 8);
      return;
    }

    // Three progress rings side by side
    final ringAreaY = 22.0;
    final ringAreaH = h - ringAreaY - 40;
    final ringRadius = (ringAreaH / 2).clamp(16.0, 36.0);
    final ringSpacing = w / 3;
    final ringCenterY = ringAreaY + ringAreaH / 2;

    // Move ring (steps)
    final moveProgress = (data.steps / data.stepGoal).clamp(0.0, 1.0);
    final moveCx = ringSpacing * 0.5;
    HudDraw.progressRing(canvas, Offset(moveCx, ringCenterY), ringRadius,
        moveProgress, strokeWidth: 4);
    HudDraw.icon(canvas, Offset(moveCx - 6, ringCenterY - 6),
        HudIcon.steps, 12);

    // Exercise ring (minutes, goal = 30)
    final exerciseProgress = (data.exerciseMinutes / 30).clamp(0.0, 1.0);
    final exCx = ringSpacing * 1.5;
    HudDraw.progressRing(canvas, Offset(exCx, ringCenterY), ringRadius,
        exerciseProgress, strokeWidth: 4);
    HudDraw.icon(canvas, Offset(exCx - 6, ringCenterY - 6),
        HudIcon.heart, 12);

    // Stand ring (hours, goal = 12)
    final standProgress = (data.standHours / 12).clamp(0.0, 1.0);
    final standCx = ringSpacing * 2.5;
    HudDraw.progressRing(canvas, Offset(standCx, ringCenterY), ringRadius,
        standProgress, strokeWidth: 4);
    HudDraw.icon(canvas, Offset(standCx - 6, ringCenterY - 6),
        HudIcon.timer, 12);

    // Numeric labels below rings
    final labelY = ringCenterY + ringRadius + 6;
    _drawCenteredLabel(canvas, moveCx, labelY, '${data.steps}',
        'MOVE', w / 3 - 4);
    _drawCenteredLabel(canvas, exCx, labelY, '${data.exerciseMinutes}m',
        'EXERCISE', w / 3 - 4);
    _drawCenteredLabel(canvas, standCx, labelY, '${data.standHours}h',
        'STAND', w / 3 - 4);

    // Step progress bar at bottom
    final barY = h - 14.0;
    HudDraw.text(canvas, '${data.steps}/${data.stepGoal}',
        Offset(4, barY - 12), fontSize: 9);
    HudDraw.progressBar(
      canvas,
      ui.Rect.fromLTWH(4, barY, w - 8, 8),
      moveProgress,
    );
  }

  void _drawCenteredLabel(ui.Canvas canvas, double cx, double y,
      String value, String label, double maxW) {
    final valueSize = HudDraw.measure(value, fontSize: 12, weight: FontWeight.bold);
    HudDraw.text(canvas, value, Offset(cx - valueSize.width / 2, y),
        fontSize: 12, weight: FontWeight.bold, maxWidth: maxW);

    final labelSize = HudDraw.measure(label, fontSize: 8);
    HudDraw.text(canvas, label, Offset(cx - labelSize.width / 2, y + 14),
        fontSize: 8, maxWidth: maxW);
  }
}
