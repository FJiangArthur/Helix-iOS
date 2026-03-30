import 'dart:ui' as ui;

import 'package:flutter/painting.dart';

import '../../hud_widgets/todos_widget.dart';
import '../bmp_widget.dart';
import '../display_constants.dart';
import '../draw_helpers.dart';

/// Todo list with progress bar and checkbox items.
class BmpTodosWidget extends BmpWidget {
  @override
  String get id => 'enh_todos';

  @override
  String get displayName => 'Todos';

  @override
  Duration get refreshInterval => const Duration(minutes: 1);

  @override
  Future<void> refresh() async {
    // cachedTodos is updated by TodosWidget.refresh() or mutation helpers.
    // Nothing extra to fetch — just mark dirty so we re-render with latest data.
    lastRefreshed = DateTime.now();
  }

  @override
  void renderToCanvas(ui.Canvas canvas, HudZone zone) {
    final w = zone.width.toDouble();
    final h = zone.height.toDouble();
    final items = TodosWidget.cachedTodos;

    // Title
    HudDraw.icon(canvas, Offset.zero, HudIcon.todo, 16);
    HudDraw.text(canvas, 'TODOS', const Offset(20, 0),
        fontSize: 12, weight: FontWeight.bold);

    if (items.isEmpty) {
      HudDraw.text(canvas, 'No todos', const Offset(4, 22),
          fontSize: 13, maxWidth: w - 8);
      return;
    }

    // Progress bar
    final doneCount = items.where((i) => i['done'] == true).length;
    final total = items.length;
    final progress = total > 0 ? doneCount / total : 0.0;
    final progressLabel = '$doneCount/$total done';
    HudDraw.text(canvas, progressLabel, Offset(w - 70, 0), fontSize: 10);
    HudDraw.progressBar(
      canvas,
      ui.Rect.fromLTWH(4, 18, w - 8, 8),
      progress,
    );

    // Todo items with checkboxes
    var yOffset = 32.0;
    const itemH = 18.0;
    const checkSize = 12.0;
    final maxItems = ((h - yOffset) / itemH).floor();

    for (int i = 0; i < items.length && i < maxItems; i++) {
      final item = items[i];
      final done = item['done'] as bool? ?? false;
      final text = item['text'] as String? ?? '';

      // Checkbox
      HudDraw.checkbox(canvas, Offset(4, yOffset + 1), checkSize, done);

      // Text (strikethrough effect for done items)
      var displayText = text;
      if (displayText.length > 24) {
        displayText = '${displayText.substring(0, 21)}...';
      }
      HudDraw.text(canvas, displayText, Offset(22, yOffset),
          fontSize: 12, maxWidth: w - 26);

      // Strikethrough line for completed items
      if (done) {
        final textSize = HudDraw.measure(displayText, fontSize: 12);
        HudDraw.hLine(canvas, 22, yOffset + textSize.height / 2,
            textSize.width.clamp(0, w - 26), thickness: 1);
      }

      yOffset += itemH;
    }

    // Show remaining count if truncated
    if (items.length > maxItems) {
      final remaining = items.length - maxItems;
      HudDraw.text(canvas, '+$remaining more', Offset(4, yOffset),
          fontSize: 9);
    }
  }
}
