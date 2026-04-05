import 'dart:ui' as ui;

import 'package:flutter/painting.dart';

import '../bmp_widget.dart';
import '../display_constants.dart';
import '../draw_helpers.dart';
import '../enhanced_data_provider.dart';

/// System/device metrics: phone battery, glasses battery, BLE status, uptime.
class BmpSystemWidget extends BmpWidget {
  DateTime? _sessionStart;

  @override
  String get id => 'enh_system';

  @override
  String get displayName => 'System';

  @override
  Duration get refreshInterval => const Duration(minutes: 2);

  @override
  Future<void> refresh() async {
    _sessionStart ??= DateTime.now();
    lastRefreshed = DateTime.now();
  }

  @override
  void renderToCanvas(ui.Canvas canvas, HudZone zone) {
    final w = zone.width.toDouble();
    final data = EnhancedDataProvider.instance;

    HudDraw.icon(canvas, Offset.zero, HudIcon.phone, 10);
    HudDraw.text(canvas, 'SYSTEM', const Offset(12, 0), fontSize: 10, weight: FontWeight.bold);

    var yOffset = 14.0;
    final barWidth = w - 40;

    HudDraw.text(canvas, 'Phone', Offset(2, yOffset), fontSize: 10);
    final phonePct = (data.phoneBattery * 100).round();
    HudDraw.text(canvas, '$phonePct%', Offset(w - 24, yOffset), fontSize: 10);
    yOffset += 12;
    HudDraw.progressBar(canvas, ui.Rect.fromLTWH(2, yOffset, barWidth, 6), data.phoneBattery);
    yOffset += 10;

    HudDraw.text(canvas, 'Glasses', Offset(2, yOffset), fontSize: 10);
    final glassPct = (data.glassesBattery * 100).round();
    HudDraw.text(canvas, '$glassPct%', Offset(w - 24, yOffset), fontSize: 10);
    yOffset += 12;
    HudDraw.progressBar(canvas, ui.Rect.fromLTWH(2, yOffset, barWidth, 6), data.glassesBattery);
    yOffset += 10;

    HudDraw.text(canvas, 'BLE', Offset(2, yOffset), fontSize: 10);
    HudDraw.text(canvas, data.bleConnected ? 'OK' : 'OFF', Offset(24, yOffset), fontSize: 10);
  }
}
