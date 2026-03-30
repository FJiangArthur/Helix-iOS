import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';

/// Reusable drawing primitives for bitmap HUD widgets.
///
/// All drawing uses white paint on black background — the BMP encoder maps
/// white to index 1 (green on G1 display). Anti-aliasing is disabled for
/// clean 1-bit output.
class HudDraw {
  HudDraw._();

  static final Paint _paint = Paint()
    ..color = const Color(0xFFFFFFFF)
    ..style = PaintingStyle.fill
    ..isAntiAlias = false;

  static final Paint _strokePaint = Paint()
    ..color = const Color(0xFFFFFFFF)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2
    ..isAntiAlias = false;

  /// Measure text size without drawing. Useful for centering calculations.
  static Size measure(
    String text, {
    double fontSize = 16,
    FontWeight weight = FontWeight.normal,
    String? fontFamily,
    double? maxWidth,
  }) {
    final style = TextStyle(
      color: const Color(0xFFFFFFFF),
      fontSize: fontSize,
      fontWeight: weight,
      fontFamily: fontFamily,
      height: 1.2,
    );
    final span = TextSpan(text: text, style: style);
    final painter = TextPainter(
      text: span,
      textDirection: TextDirection.ltr,
    );
    painter.layout(maxWidth: maxWidth ?? double.infinity);
    final size = painter.size;
    painter.dispose();
    return size;
  }

  /// Draw text onto [canvas] at [offset]. Returns the size of the rendered text.
  static Size text(
    ui.Canvas canvas,
    String text,
    Offset offset, {
    double fontSize = 16,
    FontWeight weight = FontWeight.normal,
    String? fontFamily,
    TextAlign textAlign = TextAlign.left,
    double? maxWidth,
  }) {
    final style = TextStyle(
      color: const Color(0xFFFFFFFF),
      fontSize: fontSize,
      fontWeight: weight,
      fontFamily: fontFamily,
      height: 1.2,
    );
    final span = TextSpan(text: text, style: style);
    final painter = TextPainter(
      text: span,
      textDirection: TextDirection.ltr,
      textAlign: textAlign,
    );
    painter.layout(maxWidth: maxWidth ?? double.infinity);
    painter.paint(canvas, offset);
    final size = painter.size;
    painter.dispose();
    return size;
  }

  /// Draw a horizontal line.
  static void hLine(ui.Canvas canvas, double x, double y, double width,
      {double thickness = 2}) {
    canvas.drawRect(
      Rect.fromLTWH(x, y, width, thickness),
      _paint,
    );
  }

  /// Draw a vertical line.
  static void vLine(ui.Canvas canvas, double x, double y, double height,
      {double thickness = 2}) {
    canvas.drawRect(
      Rect.fromLTWH(x, y, thickness, height),
      _paint,
    );
  }

  /// Draw a dashed horizontal line.
  static void dashedHLine(ui.Canvas canvas, double x, double y, double width,
      {double dashWidth = 6, double gapWidth = 4, double thickness = 2}) {
    double cx = x;
    while (cx < x + width) {
      final dw = (cx + dashWidth > x + width) ? (x + width - cx) : dashWidth;
      canvas.drawRect(
        Rect.fromLTWH(cx, y, dw, thickness),
        _paint,
      );
      cx += dashWidth + gapWidth;
    }
  }

  /// Draw a sparkline chart within [bounds] from [values].
  ///
  /// Scales values to fill the vertical space. Draws a polyline path.
  static void sparkline(ui.Canvas canvas, Rect bounds, List<double> values,
      {double strokeWidth = 2}) {
    if (values.length < 2) return;

    final minVal = values.reduce((a, b) => a < b ? a : b);
    final maxVal = values.reduce((a, b) => a > b ? a : b);
    final range = maxVal - minVal;
    if (range == 0) return;

    final path = ui.Path();
    final stepX = bounds.width / (values.length - 1);

    for (int i = 0; i < values.length; i++) {
      final x = bounds.left + i * stepX;
      // Invert Y: high values at top
      final normalized = (values[i] - minVal) / range;
      final y = bounds.bottom - normalized * bounds.height;

      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    final paint = Paint()
      ..color = const Color(0xFFFFFFFF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..isAntiAlias = false;
    canvas.drawPath(path, paint);
  }

  /// Draw a simple procedural icon by name.
  static void icon(ui.Canvas canvas, Offset offset, HudIcon icon,
      double size) {
    switch (icon) {
      case HudIcon.bell:
        _drawBellIcon(canvas, offset, size);
      case HudIcon.battery:
        _drawBatteryIcon(canvas, offset, size, fillPercent: 1.0);
      case HudIcon.calendar:
        _drawCalendarIcon(canvas, offset, size);
      case HudIcon.sun:
        _drawSunIcon(canvas, offset, size);
      case HudIcon.cloud:
        _drawCloudIcon(canvas, offset, size);
      case HudIcon.rain:
        _drawRainIcon(canvas, offset, size);
      case HudIcon.snow:
        _drawSnowIcon(canvas, offset, size);
      case HudIcon.thermometer:
        _drawThermometerIcon(canvas, offset, size);
      case HudIcon.mic:
        _drawMicIcon(canvas, offset, size);
      case HudIcon.stockUp:
        _drawArrowIcon(canvas, offset, size, up: true);
      case HudIcon.stockDown:
        _drawArrowIcon(canvas, offset, size, up: false);
      case HudIcon.steps:
        _drawStepsIcon(canvas, offset, size);
      case HudIcon.heart:
        _drawHeartIcon(canvas, offset, size);
      case HudIcon.timer:
        _drawTimerIcon(canvas, offset, size);
      case HudIcon.news:
        _drawNewsIcon(canvas, offset, size);
      case HudIcon.todo:
        _drawTodoIcon(canvas, offset, size);
      case HudIcon.wifi:
        _drawWifiIcon(canvas, offset, size);
      case HudIcon.phone:
        _drawPhoneIcon(canvas, offset, size);
      case HudIcon.trending:
        _drawArrowIcon(canvas, offset, size, up: true);
      case HudIcon.activity:
        _drawActivityIcon(canvas, offset, size);
      case HudIcon.compass:
        _drawCompassIcon(canvas, offset, size);
    }
  }

  /// Draw battery icon with fill level (0.0-1.0).
  static void batteryIcon(ui.Canvas canvas, Offset offset, double size,
      {double fillPercent = 1.0}) {
    _drawBatteryIcon(canvas, offset, size, fillPercent: fillPercent);
  }

  // --- Icon implementations ---

  static void _drawBellIcon(ui.Canvas canvas, Offset o, double s) {
    final cx = o.dx + s / 2;
    // Bell body (arc shape approximated with oval)
    canvas.drawOval(
      Rect.fromCenter(
          center: Offset(cx, o.dy + s * 0.45), width: s * 0.6, height: s * 0.6),
      _paint,
    );
    // Bell base
    canvas.drawRect(
      Rect.fromLTWH(o.dx + s * 0.15, o.dy + s * 0.65, s * 0.7, s * 0.1),
      _paint,
    );
    // Clapper
    canvas.drawCircle(Offset(cx, o.dy + s * 0.85), s * 0.08, _paint);
  }

  static void _drawBatteryIcon(ui.Canvas canvas, Offset o, double s,
      {double fillPercent = 1.0}) {
    final bodyW = s * 0.7;
    final bodyH = s * 0.4;
    final bodyX = o.dx + (s - bodyW) / 2;
    final bodyY = o.dy + (s - bodyH) / 2;

    // Outline
    canvas.drawRect(
      Rect.fromLTWH(bodyX, bodyY, bodyW, bodyH),
      _strokePaint,
    );
    // Terminal nub
    canvas.drawRect(
      Rect.fromLTWH(bodyX + bodyW, bodyY + bodyH * 0.25, s * 0.08, bodyH * 0.5),
      _paint,
    );
    // Fill
    final fillW = (bodyW - 4) * fillPercent.clamp(0.0, 1.0);
    if (fillW > 0) {
      canvas.drawRect(
        Rect.fromLTWH(bodyX + 2, bodyY + 2, fillW, bodyH - 4),
        _paint,
      );
    }
  }

  static void _drawCalendarIcon(ui.Canvas canvas, Offset o, double s) {
    // Outer box
    canvas.drawRect(
      Rect.fromLTWH(o.dx + s * 0.1, o.dy + s * 0.15, s * 0.8, s * 0.75),
      _strokePaint,
    );
    // Top bar
    canvas.drawRect(
      Rect.fromLTWH(o.dx + s * 0.1, o.dy + s * 0.15, s * 0.8, s * 0.15),
      _paint,
    );
    // Grid dots (3x2)
    for (int r = 0; r < 2; r++) {
      for (int c = 0; c < 3; c++) {
        canvas.drawRect(
          Rect.fromLTWH(
            o.dx + s * 0.22 + c * s * 0.22,
            o.dy + s * 0.45 + r * s * 0.18,
            s * 0.1,
            s * 0.08,
          ),
          _paint,
        );
      }
    }
  }

  static void _drawSunIcon(ui.Canvas canvas, Offset o, double s) {
    final cx = o.dx + s / 2;
    final cy = o.dy + s / 2;
    // Center circle
    canvas.drawCircle(Offset(cx, cy), s * 0.2, _paint);
    // Rays (8 directions)
    final rayPaint = Paint()
      ..color = const Color(0xFFFFFFFF)
      ..strokeWidth = 2
      ..isAntiAlias = false;
    for (int i = 0; i < 8; i++) {
      final angle = i * math.pi / 4;
      final innerR = s * 0.28;
      final outerR = s * 0.42;
      canvas.drawLine(
        Offset(cx + innerR * _cos(angle), cy + innerR * _sin(angle)),
        Offset(cx + outerR * _cos(angle), cy + outerR * _sin(angle)),
        rayPaint,
      );
    }
  }

  static void _drawCloudIcon(ui.Canvas canvas, Offset o, double s) {
    final cx = o.dx + s / 2;
    final cy = o.dy + s * 0.5;
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx - s * 0.1, cy), width: s * 0.5, height: s * 0.35),
      _paint,
    );
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx + s * 0.15, cy - s * 0.05), width: s * 0.45, height: s * 0.3),
      _paint,
    );
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx + s * 0.05, cy + s * 0.05), width: s * 0.6, height: s * 0.25),
      _paint,
    );
  }

  static void _drawRainIcon(ui.Canvas canvas, Offset o, double s) {
    // Cloud
    _drawCloudIcon(canvas, Offset(o.dx, o.dy - s * 0.1), s);
    // Rain drops
    final dropPaint = Paint()
      ..color = const Color(0xFFFFFFFF)
      ..strokeWidth = 2
      ..isAntiAlias = false;
    for (int i = 0; i < 3; i++) {
      final dx = o.dx + s * 0.25 + i * s * 0.2;
      canvas.drawLine(
        Offset(dx, o.dy + s * 0.6),
        Offset(dx - s * 0.05, o.dy + s * 0.8),
        dropPaint,
      );
    }
  }

  static void _drawSnowIcon(ui.Canvas canvas, Offset o, double s) {
    _drawCloudIcon(canvas, Offset(o.dx, o.dy - s * 0.1), s);
    // Snowflakes (dots)
    for (int i = 0; i < 3; i++) {
      final dx = o.dx + s * 0.25 + i * s * 0.2;
      canvas.drawCircle(Offset(dx, o.dy + s * 0.7), s * 0.04, _paint);
      canvas.drawCircle(Offset(dx + s * 0.1, o.dy + s * 0.85), s * 0.04, _paint);
    }
  }

  static void _drawThermometerIcon(ui.Canvas canvas, Offset o, double s) {
    final cx = o.dx + s / 2;
    // Tube
    canvas.drawRect(
      Rect.fromLTWH(cx - s * 0.06, o.dy + s * 0.1, s * 0.12, s * 0.55),
      _strokePaint,
    );
    // Bulb
    canvas.drawCircle(Offset(cx, o.dy + s * 0.78), s * 0.14, _paint);
    // Mercury
    canvas.drawRect(
      Rect.fromLTWH(cx - s * 0.03, o.dy + s * 0.35, s * 0.06, s * 0.35),
      _paint,
    );
  }

  static void _drawMicIcon(ui.Canvas canvas, Offset o, double s) {
    final cx = o.dx + s / 2;
    // Mic head
    canvas.drawOval(
      Rect.fromCenter(
          center: Offset(cx, o.dy + s * 0.3), width: s * 0.3, height: s * 0.4),
      _paint,
    );
    // Stand
    canvas.drawRect(
      Rect.fromLTWH(cx - s * 0.04, o.dy + s * 0.55, s * 0.08, s * 0.2),
      _paint,
    );
    // Base
    canvas.drawRect(
      Rect.fromLTWH(cx - s * 0.15, o.dy + s * 0.75, s * 0.3, s * 0.06),
      _paint,
    );
  }

  static void _drawArrowIcon(ui.Canvas canvas, Offset o, double s,
      {required bool up}) {
    final cx = o.dx + s / 2;
    final path = ui.Path();
    if (up) {
      path.moveTo(cx, o.dy + s * 0.2);
      path.lineTo(cx + s * 0.3, o.dy + s * 0.55);
      path.lineTo(cx - s * 0.3, o.dy + s * 0.55);
    } else {
      path.moveTo(cx, o.dy + s * 0.8);
      path.lineTo(cx + s * 0.3, o.dy + s * 0.45);
      path.lineTo(cx - s * 0.3, o.dy + s * 0.45);
    }
    path.close();
    canvas.drawPath(path, _paint);
  }

  // --- Drawing primitives ---

  /// Draw a horizontal progress bar with optional label.
  static void progressBar(ui.Canvas canvas, Rect bounds, double value,
      {String? label}) {
    final v = value.clamp(0.0, 1.0);
    // Outline
    canvas.drawRect(bounds, _strokePaint);
    // Fill
    final fillW = (bounds.width - 4) * v;
    if (fillW > 0) {
      canvas.drawRect(
        Rect.fromLTWH(bounds.left + 2, bounds.top + 2, fillW, bounds.height - 4),
        _paint,
      );
    }
    // Label
    if (label != null) {
      final labelSize = measure(label, fontSize: 10);
      final lx = bounds.left + (bounds.width - labelSize.width) / 2;
      final ly = bounds.top + (bounds.height - labelSize.height) / 2;
      // Draw black background for label readability
      final bgPaint = Paint()
        ..color = const Color(0xFF000000)
        ..isAntiAlias = false;
      canvas.drawRect(
        Rect.fromLTWH(lx - 2, ly, labelSize.width + 4, labelSize.height),
        bgPaint,
      );
      text(canvas, label, Offset(lx, ly), fontSize: 10);
    }
  }

  /// Draw a circular progress ring (arc gauge) using polyline segments.
  static void progressRing(ui.Canvas canvas, Offset center, double radius,
      double value, {double strokeWidth = 3}) {
    final v = value.clamp(0.0, 1.0);
    // Background ring — dashed white on 1-bit display (no gray available)
    final bgPaint = Paint()
      ..color = const Color(0xFFFFFFFF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..isAntiAlias = false;
    _drawDashedArc(canvas, center, radius, 0, 2 * math.pi, bgPaint, 48);
    // Foreground ring
    if (v > 0) {
      final fgPaint = Paint()
        ..color = const Color(0xFFFFFFFF)
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..isAntiAlias = false;
      final sweepAngle = v * 2 * math.pi;
      _drawArc(canvas, center, radius, -math.pi / 2, sweepAngle, fgPaint, 48);
    }
  }

  /// Draw a dashed arc for background rings on 1-bit displays.
  static void _drawDashedArc(ui.Canvas canvas, Offset center, double radius,
      double startAngle, double sweepAngle, Paint paint, int segments) {
    // Draw every other segment to create a dashed appearance
    for (int i = 0; i < segments; i += 2) {
      final t0 = i / segments;
      final t1 = (i + 1) / segments;
      final a0 = startAngle + sweepAngle * t0;
      final a1 = startAngle + sweepAngle * t1;
      canvas.drawLine(
        Offset(center.dx + radius * _cos(a0), center.dy + radius * _sin(a0)),
        Offset(center.dx + radius * _cos(a1), center.dy + radius * _sin(a1)),
        paint,
      );
    }
  }

  /// Draw an arc as a polyline with [segments] line segments.
  static void _drawArc(ui.Canvas canvas, Offset center, double radius,
      double startAngle, double sweepAngle, Paint paint, int segments) {
    final path = ui.Path();
    for (int i = 0; i <= segments; i++) {
      final t = i / segments;
      final angle = startAngle + sweepAngle * t;
      final x = center.dx + radius * _cos(angle);
      final y = center.dy + radius * _sin(angle);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(path, paint);
  }

  /// Draw a vertical bar chart within [bounds].
  static void barChart(ui.Canvas canvas, Rect bounds, List<double> values,
      {List<String>? labels}) {
    if (values.isEmpty) return;
    final maxVal = values.reduce((a, b) => a > b ? a : b);
    if (maxVal <= 0) return;

    final barCount = values.length;
    final gap = 2.0;
    final barW = (bounds.width - gap * (barCount - 1)) / barCount;

    for (int i = 0; i < barCount; i++) {
      final normalized = values[i].clamp(0.0, maxVal) / maxVal;
      final barH = normalized * (bounds.height - (labels != null ? 14 : 0));
      final x = bounds.left + i * (barW + gap);
      final y = bounds.top + bounds.height - barH - (labels != null ? 14 : 0);
      canvas.drawRect(Rect.fromLTWH(x, y, barW, barH), _paint);

      if (labels != null && i < labels.length) {
        text(canvas, labels[i],
            Offset(x, bounds.bottom - 12), fontSize: 9, maxWidth: barW);
      }
    }
  }

  /// Draw a semi-circular gauge with needle.
  static void gauge(ui.Canvas canvas, Offset center, double radius,
      double value, {double min = 0, double max = 1, String? label}) {
    final range = max - min;
    final v = range == 0 ? 0.0 : ((value - min) / range).clamp(0.0, 1.0);
    // Draw arc background
    final arcPaint = Paint()
      ..color = const Color(0xFFFFFFFF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..isAntiAlias = false;
    _drawArc(canvas, center, radius, math.pi, math.pi, arcPaint, 32);

    // Needle
    final angle = math.pi + v * math.pi;
    final nx = center.dx + (radius - 4) * _cos(angle);
    final ny = center.dy + (radius - 4) * _sin(angle);
    final needlePaint = Paint()
      ..color = const Color(0xFFFFFFFF)
      ..strokeWidth = 2
      ..isAntiAlias = false;
    canvas.drawLine(center, Offset(nx, ny), needlePaint);
    canvas.drawCircle(center, 3, _paint);

    if (label != null) {
      final s = measure(label, fontSize: 10);
      text(canvas, label,
          Offset(center.dx - s.width / 2, center.dy + 4), fontSize: 10);
    }
  }

  /// Draw a mini data table.
  static void miniTable(ui.Canvas canvas, Offset offset,
      List<List<String>> rows, {List<double>? colWidths}) {
    const rowH = 14.0;
    const fontSize = 11.0;

    for (int r = 0; r < rows.length; r++) {
      double cx = offset.dx;
      for (int c = 0; c < rows[r].length; c++) {
        final colW = (colWidths != null && c < colWidths.length)
            ? colWidths[c]
            : 80.0;
        text(canvas, rows[r][c],
            Offset(cx, offset.dy + r * rowH), fontSize: fontSize, maxWidth: colW);
        cx += colW;
      }
    }
  }

  /// Draw a checkbox icon.
  static void checkbox(ui.Canvas canvas, Offset offset, double size,
      bool checked) {
    // Box outline
    canvas.drawRect(
      Rect.fromLTWH(offset.dx, offset.dy, size, size),
      _strokePaint,
    );
    if (checked) {
      // Checkmark
      final p = Paint()
        ..color = const Color(0xFFFFFFFF)
        ..strokeWidth = 2
        ..isAntiAlias = false;
      canvas.drawLine(
        Offset(offset.dx + size * 0.2, offset.dy + size * 0.5),
        Offset(offset.dx + size * 0.4, offset.dy + size * 0.75),
        p,
      );
      canvas.drawLine(
        Offset(offset.dx + size * 0.4, offset.dy + size * 0.75),
        Offset(offset.dx + size * 0.8, offset.dy + size * 0.25),
        p,
      );
    }
  }

  /// Draw a dashed border rectangle.
  static void dashedRect(ui.Canvas canvas, Rect bounds,
      {double dashWidth = 6, double gapWidth = 4, double thickness = 1}) {
    dashedHLine(canvas, bounds.left, bounds.top, bounds.width,
        dashWidth: dashWidth, gapWidth: gapWidth, thickness: thickness);
    dashedHLine(canvas, bounds.left, bounds.bottom - thickness, bounds.width,
        dashWidth: dashWidth, gapWidth: gapWidth, thickness: thickness);
    // Vertical dashes (approximate with small rects)
    double cy = bounds.top;
    while (cy < bounds.bottom) {
      final dh = (cy + dashWidth > bounds.bottom) ? (bounds.bottom - cy) : dashWidth;
      canvas.drawRect(
        Rect.fromLTWH(bounds.left, cy, thickness, dh), _paint);
      canvas.drawRect(
        Rect.fromLTWH(bounds.right - thickness, cy, thickness, dh), _paint);
      cy += dashWidth + gapWidth;
    }
  }

  /// Draw a rounded rectangle outline.
  static void roundedRect(ui.Canvas canvas, Rect bounds, double radius) {
    final rrect = RRect.fromRectAndRadius(bounds, Radius.circular(radius));
    canvas.drawRRect(rrect, _strokePaint);
  }

  // --- New icon implementations ---

  static void _drawStepsIcon(ui.Canvas canvas, Offset o, double s) {
    // Footprint icon: two offset ovals
    canvas.drawOval(
      Rect.fromCenter(center: Offset(o.dx + s * 0.35, o.dy + s * 0.3),
          width: s * 0.25, height: s * 0.4), _paint);
    canvas.drawOval(
      Rect.fromCenter(center: Offset(o.dx + s * 0.6, o.dy + s * 0.6),
          width: s * 0.25, height: s * 0.4), _paint);
  }

  static void _drawHeartIcon(ui.Canvas canvas, Offset o, double s) {
    final cx = o.dx + s / 2;
    // Two circles for top bumps
    canvas.drawCircle(Offset(cx - s * 0.15, o.dy + s * 0.35), s * 0.2, _paint);
    canvas.drawCircle(Offset(cx + s * 0.15, o.dy + s * 0.35), s * 0.2, _paint);
    // Triangle for bottom
    final path = ui.Path();
    path.moveTo(cx - s * 0.35, o.dy + s * 0.4);
    path.lineTo(cx, o.dy + s * 0.85);
    path.lineTo(cx + s * 0.35, o.dy + s * 0.4);
    path.close();
    canvas.drawPath(path, _paint);
  }

  static void _drawTimerIcon(ui.Canvas canvas, Offset o, double s) {
    final cx = o.dx + s / 2;
    final cy = o.dy + s * 0.55;
    canvas.drawCircle(Offset(cx, cy), s * 0.35, _strokePaint);
    // Top nub
    canvas.drawRect(
      Rect.fromLTWH(cx - s * 0.06, o.dy + s * 0.1, s * 0.12, s * 0.1), _paint);
    // Hands
    final handPaint = Paint()
      ..color = const Color(0xFFFFFFFF)
      ..strokeWidth = 2
      ..isAntiAlias = false;
    canvas.drawLine(Offset(cx, cy), Offset(cx, cy - s * 0.22), handPaint);
    canvas.drawLine(Offset(cx, cy), Offset(cx + s * 0.15, cy), handPaint);
  }

  static void _drawNewsIcon(ui.Canvas canvas, Offset o, double s) {
    // Document with lines
    canvas.drawRect(
      Rect.fromLTWH(o.dx + s * 0.15, o.dy + s * 0.1, s * 0.7, s * 0.8),
      _strokePaint);
    for (int i = 0; i < 3; i++) {
      canvas.drawRect(
        Rect.fromLTWH(o.dx + s * 0.25, o.dy + s * 0.25 + i * s * 0.2,
            s * 0.5, s * 0.06), _paint);
    }
  }

  static void _drawTodoIcon(ui.Canvas canvas, Offset o, double s) {
    checkbox(canvas, Offset(o.dx + s * 0.1, o.dy + s * 0.15), s * 0.3, true);
    canvas.drawRect(
      Rect.fromLTWH(o.dx + s * 0.5, o.dy + s * 0.22, s * 0.35, s * 0.06),
      _paint);
    checkbox(canvas, Offset(o.dx + s * 0.1, o.dy + s * 0.55), s * 0.3, false);
    canvas.drawRect(
      Rect.fromLTWH(o.dx + s * 0.5, o.dy + s * 0.62, s * 0.35, s * 0.06),
      _paint);
  }

  static void _drawWifiIcon(ui.Canvas canvas, Offset o, double s) {
    final cx = o.dx + s / 2;
    // Three arcs of increasing radius
    for (int i = 0; i < 3; i++) {
      final r = s * (0.15 + i * 0.12);
      final arcPaint = Paint()
        ..color = const Color(0xFFFFFFFF)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..isAntiAlias = false;
      _drawArc(canvas, Offset(cx, o.dy + s * 0.7), r,
          -math.pi * 0.75, math.pi * 0.5, arcPaint, 16);
    }
    // Dot at bottom
    canvas.drawCircle(Offset(cx, o.dy + s * 0.7), s * 0.05, _paint);
  }

  static void _drawPhoneIcon(ui.Canvas canvas, Offset o, double s) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(o.dx + s * 0.3, o.dy + s * 0.1, s * 0.4, s * 0.8),
        Radius.circular(s * 0.06)),
      _strokePaint);
    // Screen area
    canvas.drawRect(
      Rect.fromLTWH(o.dx + s * 0.35, o.dy + s * 0.2, s * 0.3, s * 0.5),
      _paint);
  }

  static void _drawActivityIcon(ui.Canvas canvas, Offset o, double s) {
    final cx = o.dx + s / 2;
    final cy = o.dy + s / 2;
    // Three concentric ring arcs (like Apple Watch)
    for (int i = 0; i < 3; i++) {
      final r = s * (0.15 + i * 0.1);
      final arcPaint = Paint()
        ..color = const Color(0xFFFFFFFF)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..isAntiAlias = false;
      _drawArc(canvas, Offset(cx, cy), r, -math.pi / 2,
          math.pi * (1.2 + i * 0.3), arcPaint, 24);
    }
  }

  static void _drawCompassIcon(ui.Canvas canvas, Offset o, double s) {
    final cx = o.dx + s / 2;
    final cy = o.dy + s / 2;
    canvas.drawCircle(Offset(cx, cy), s * 0.4, _strokePaint);
    // North needle
    final path = ui.Path();
    path.moveTo(cx, o.dy + s * 0.15);
    path.lineTo(cx - s * 0.08, cy);
    path.lineTo(cx + s * 0.08, cy);
    path.close();
    canvas.drawPath(path, _paint);
    canvas.drawCircle(Offset(cx, cy), s * 0.05, _paint);
  }

  static double _cos(double radians) => math.cos(radians);
  static double _sin(double radians) => math.sin(radians);
}

/// Available procedural icons for the HUD.
enum HudIcon {
  bell,
  battery,
  calendar,
  sun,
  cloud,
  rain,
  snow,
  thermometer,
  mic,
  stockUp,
  stockDown,
  steps,
  heart,
  timer,
  news,
  todo,
  wifi,
  phone,
  trending,
  activity,
  compass,
}
