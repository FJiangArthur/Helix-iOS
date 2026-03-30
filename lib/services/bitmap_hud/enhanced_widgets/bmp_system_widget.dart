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

    // Title
    HudDraw.icon(canvas, Offset.zero, HudIcon.phone, 16);
    HudDraw.text(
      canvas,
      'SYSTEM',
      const Offset(20, 0),
      fontSize: 12,
      weight: FontWeight.bold,
    );

    var yOffset = 22.0;
    final barWidth = w - 60;

    // Phone battery
    HudDraw.text(canvas, 'Phone', Offset(4, yOffset), fontSize: 11);
    final phonePct = (data.phoneBattery * 100).round();
    HudDraw.text(canvas, '$phonePct%', Offset(w - 30, yOffset), fontSize: 11);
    yOffset += 14;
    HudDraw.progressBar(
      canvas,
      ui.Rect.fromLTWH(4, yOffset, barWidth, 10),
      data.phoneBattery,
    );
    HudDraw.batteryIcon(
      canvas,
      Offset(barWidth + 10, yOffset - 4),
      18,
      fillPercent: data.phoneBattery,
    );
    yOffset += 18;

    // Glasses battery
    HudDraw.text(canvas, 'Glasses', Offset(4, yOffset), fontSize: 11);
    final glassPct = (data.glassesBattery * 100).round();
    HudDraw.text(canvas, '$glassPct%', Offset(w - 30, yOffset), fontSize: 11);
    yOffset += 14;
    HudDraw.progressBar(
      canvas,
      ui.Rect.fromLTWH(4, yOffset, barWidth, 10),
      data.glassesBattery,
    );
    HudDraw.batteryIcon(
      canvas,
      Offset(barWidth + 10, yOffset - 4),
      18,
      fillPercent: data.glassesBattery,
    );
    yOffset += 22;

    // BLE Connection status
    HudDraw.text(canvas, 'BLE', Offset(4, yOffset), fontSize: 11);
    if (data.bleConnected) {
      HudDraw.icon(canvas, Offset(36, yOffset - 2), HudIcon.wifi, 14);
      HudDraw.text(canvas, 'Connected', Offset(54, yOffset), fontSize: 11);
    } else {
      HudDraw.text(canvas, 'Disconnected', Offset(36, yOffset), fontSize: 11);
    }
    yOffset += 18;

    // Session uptime
    if (_sessionStart != null) {
      final uptime = DateTime.now().difference(_sessionStart!);
      final hours = uptime.inHours;
      final mins = uptime.inMinutes % 60;
      HudDraw.text(canvas, 'Uptime', Offset(4, yOffset), fontSize: 11);
      HudDraw.text(
        canvas,
        '${hours}h ${mins}m',
        Offset(54, yOffset),
        fontSize: 11,
      );
    }
  }
}
