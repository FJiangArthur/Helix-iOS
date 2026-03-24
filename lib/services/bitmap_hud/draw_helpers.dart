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
}
