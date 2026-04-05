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

    HudDraw.icon(canvas, Offset.zero, HudIcon.news, 10);
    HudDraw.text(canvas, 'NEWS', const Offset(12, 0), fontSize: 9, weight: FontWeight.bold);

    if (headlines.isEmpty) {
      HudDraw.text(canvas, 'No headlines', const Offset(2, 14), fontSize: 10, maxWidth: w - 4);
      return;
    }

    var yOffset = 14.0;
    final maxChars = (w / 6).floor();
    final maxHeadlines = ((h - yOffset) / 14).floor().clamp(1, 5);

    for (int i = 0; i < headlines.length && i < maxHeadlines; i++) {
      var headline = headlines[i];
      if (headline.length > maxChars) headline = '${headline.substring(0, maxChars - 3)}...';

      HudDraw.text(canvas, headline, Offset(2, yOffset), fontSize: 9, maxWidth: w - 4);
      yOffset += 14;
      if (yOffset > h - 4) break;
    }
  }
}
