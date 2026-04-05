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

    HudDraw.icon(canvas, Offset.zero, HudIcon.todo, 10);
    HudDraw.text(canvas, 'TODOS', const Offset(12, 0), fontSize: 10, weight: FontWeight.bold);

    if (items.isEmpty) {
      HudDraw.text(canvas, 'No todos', const Offset(2, 14), fontSize: 10, maxWidth: w - 4);
      return;
    }

    final doneCount = items.where((i) => i['done'] == true).length;
    final total = items.length;
    final progress = total > 0 ? doneCount / total : 0.0;
    HudDraw.text(canvas, '$doneCount/$total', Offset(w - 32, 0), fontSize: 10);
    HudDraw.progressBar(canvas, ui.Rect.fromLTWH(2, 12, w - 4, 4), progress);

    var yOffset = 20.0;
    const itemH = 12.0;
    const checkSize = 8.0;
    final maxItems = ((h - yOffset) / itemH).floor();

    for (int i = 0; i < items.length && i < maxItems; i++) {
      final item = items[i];
      final done = item['done'] as bool? ?? false;
      var text = item['text'] as String? ?? '';
      if (text.length > 20) text = '${text.substring(0, 17)}...';

      HudDraw.checkbox(canvas, Offset(2, yOffset), checkSize, done);
      HudDraw.text(canvas, text, Offset(14, yOffset), fontSize: 10, maxWidth: w - 18);

      if (done) {
        final textSize = HudDraw.measure(text, fontSize: 10);
        HudDraw.hLine(canvas, 14, yOffset + textSize.height / 2,
            textSize.width.clamp(0, w - 18), thickness: 1);
      }
      yOffset += itemH;
    }

    if (items.length > maxItems) {
      HudDraw.text(canvas, '+${items.length - maxItems} more', Offset(2, yOffset), fontSize: 10);
    }
  }
}
