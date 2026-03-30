import 'dart:ui' as ui;

import 'package:flutter/painting.dart';

import '../bmp_widget.dart';
import '../display_constants.dart';
import '../draw_helpers.dart';
import '../enhanced_data_provider.dart';

/// News headlines widget displaying 2-3 headlines with separators.
class BmpNewsWidget extends BmpWidget {
  @override
  String get id => 'enh_news';

  @override
  String get displayName => 'News';

  @override
  Duration get refreshInterval => const Duration(minutes: 15);

  @override
  Future<void> refresh() async {
    await EnhancedDataProvider.instance.refreshNews();
    lastRefreshed = DateTime.now();
  }

  @override
  void renderToCanvas(ui.Canvas canvas, HudZone zone) {
    final w = zone.width.toDouble();
    final h = zone.height.toDouble();
    final headlines = EnhancedDataProvider.instance.newsHeadlines;

    // Title
    HudDraw.icon(canvas, Offset.zero, HudIcon.news, 16);
    HudDraw.text(canvas, 'NEWS', const Offset(20, 0),
        fontSize: 12, weight: FontWeight.bold);

    if (headlines.isEmpty) {
      HudDraw.text(canvas, 'No headlines', const Offset(4, 22),
          fontSize: 13, maxWidth: w - 8);
      return;
    }

    // Calculate how many headlines fit
    final availableH = h - 20;
    final lineH = 16.0;
    // Each headline takes ~2 lines (title wraps) + separator
    final maxHeadlines = (availableH / (lineH * 2 + 8)).floor().clamp(1, 5);

    var yOffset = 20.0;
    for (int i = 0; i < headlines.length && i < maxHeadlines; i++) {
      var headline = headlines[i];

      // Calculate max chars that fit in width at font size 12
      final maxChars = (w / 7).floor(); // ~7px per char at size 12
      if (headline.length > maxChars * 2) {
        headline = '${headline.substring(0, maxChars * 2 - 3)}...';
      }

      // Source label
      HudDraw.text(canvas, '[$i]', Offset(0, yOffset),
          fontSize: 9);

      // Headline text (may wrap)
      final rendered = HudDraw.text(canvas, headline, Offset(20, yOffset),
          fontSize: 12, maxWidth: w - 24);
      yOffset += rendered.height + 4;

      // Dashed separator
      if (i < headlines.length - 1 && i < maxHeadlines - 1) {
        HudDraw.dashedHLine(canvas, 0, yOffset, w,
            dashWidth: 4, gapWidth: 3, thickness: 1);
        yOffset += 6;
      }

      if (yOffset > h - 10) break;
    }
  }
}
