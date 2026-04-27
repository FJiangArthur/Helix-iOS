import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/helix_theme.dart';

enum HelixVisualType { mark, onboarding, conversation, glasses, knowledge }

class HelixVisual extends StatelessWidget {
  final HelixVisualType type;
  final double height;
  final Color? accent;
  final bool compact;

  const HelixVisual({
    super.key,
    required this.type,
    this.height = 132,
    this.accent,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: double.infinity,
      child: CustomPaint(
        painter: _HelixVisualPainter(
          type: type,
          accent: accent ?? HelixTheme.cyan,
          compact: compact,
        ),
      ),
    );
  }
}

class _HelixVisualPainter extends CustomPainter {
  _HelixVisualPainter({
    required this.type,
    required this.accent,
    required this.compact,
  });

  final HelixVisualType type;
  final Color accent;
  final bool compact;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final radius = Radius.circular(compact ? 10 : 14);
    final bgPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          HelixTheme.surfaceRaised.withValues(alpha: 0.92),
          HelixTheme.surface.withValues(alpha: 0.86),
        ],
      ).createShader(rect);
    canvas.drawRRect(RRect.fromRectAndRadius(rect, radius), bgPaint);

    final gridPaint = Paint()
      ..color = HelixTheme.borderSubtle.withValues(alpha: 0.28)
      ..strokeWidth = 1;
    final gridStep = compact ? 28.0 : 34.0;
    for (double x = gridStep; x < size.width; x += gridStep) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (double y = gridStep; y < size.height; y += gridStep) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    final edgePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = HelixTheme.borderStrong.withValues(alpha: 0.7);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect.deflate(0.5), radius),
      edgePaint,
    );

    switch (type) {
      case HelixVisualType.mark:
        _drawMark(canvas, size);
      case HelixVisualType.onboarding:
        _drawGlasses(canvas, size, showHud: true);
        _drawSignal(canvas, size);
      case HelixVisualType.conversation:
        _drawConversation(canvas, size);
      case HelixVisualType.glasses:
        _drawGlasses(canvas, size, showHud: true);
      case HelixVisualType.knowledge:
        _drawKnowledge(canvas, size);
    }
  }

  void _drawMark(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final w = size.width * 0.42;
    final h = size.height * 0.36;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = 3
      ..color = accent;
    final rect = Rect.fromCenter(center: center, width: w, height: h);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, Radius.circular(h * 0.36)),
      paint,
    );
    canvas.drawCircle(center, math.min(w, h) * 0.18, paint);
    canvas.drawLine(
      center.translate(-w * 0.24, h * 0.22),
      center.translate(w * 0.24, -h * 0.22),
      paint..color = HelixTheme.lime,
    );
  }

  void _drawGlasses(Canvas canvas, Size size, {required bool showHud}) {
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = compact ? 2.2 : 2.8
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = accent;
    final soft = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 9
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = accent.withValues(alpha: 0.08);
    final cx = size.width / 2;
    final cy = size.height * 0.52;
    final lensW = size.width * (compact ? 0.58 : 0.66);
    final lensH = size.height * (compact ? 0.36 : 0.42);
    final lens = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(cx, cy), width: lensW, height: lensH),
      Radius.circular(lensH * 0.34),
    );
    canvas.drawRRect(lens, soft);
    canvas.drawRRect(lens, stroke);

    final armY = cy - lensH * 0.2;
    canvas.drawLine(
      Offset(cx - lensW / 2, armY),
      Offset(cx - lensW / 2 - size.width * 0.1, armY + size.height * 0.06),
      stroke,
    );
    canvas.drawLine(
      Offset(cx + lensW / 2, armY),
      Offset(cx + lensW / 2 + size.width * 0.1, armY + size.height * 0.06),
      stroke,
    );

    if (!showHud) return;
    final hudPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3
      ..strokeCap = StrokeCap.round
      ..color = HelixTheme.lime.withValues(alpha: 0.88);
    final textPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round
      ..color = HelixTheme.textSecondary.withValues(alpha: 0.72);
    for (var i = 0; i < 3; i++) {
      final y = cy - lensH * 0.1 + i * 12;
      canvas.drawLine(
        Offset(cx - lensW * 0.26, y),
        Offset(cx + lensW * 0.2, y),
        textPaint,
      );
    }
    canvas.drawCircle(
      Offset(cx + lensW * 0.29, cy - lensH * 0.05),
      5,
      hudPaint,
    );
    canvas.drawArc(
      Rect.fromCircle(
        center: Offset(cx + lensW * 0.29, cy - lensH * 0.05),
        radius: 12,
      ),
      -math.pi / 2,
      math.pi * 1.2,
      false,
      hudPaint,
    );
  }

  void _drawSignal(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round
      ..color = HelixTheme.textMuted.withValues(alpha: 0.64);
    final center = Offset(size.width * 0.2, size.height * 0.34);
    for (var i = 0; i < 3; i++) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: 18.0 + i * 12),
        -0.5,
        1.0,
        false,
        paint,
      );
    }
  }

  void _drawConversation(Canvas canvas, Size size) {
    _drawGlasses(canvas, size, showHud: true);
    final wavePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..color = HelixTheme.lime.withValues(alpha: 0.78);
    final baseY = size.height * 0.76;
    final startX = size.width * 0.18;
    final path = Path()..moveTo(startX, baseY);
    for (var i = 0; i < 9; i++) {
      final x = startX + i * size.width * 0.075;
      final y = baseY + math.sin(i * 1.3) * 10;
      path.lineTo(x, y);
    }
    canvas.drawPath(path, wavePaint);
  }

  void _drawKnowledge(Canvas canvas, Size size) {
    final nodes = <Offset>[
      Offset(size.width * 0.22, size.height * 0.62),
      Offset(size.width * 0.36, size.height * 0.36),
      Offset(size.width * 0.5, size.height * 0.56),
      Offset(size.width * 0.66, size.height * 0.3),
      Offset(size.width * 0.78, size.height * 0.66),
    ];
    final linePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..color = HelixTheme.borderStrong.withValues(alpha: 0.75);
    for (var i = 0; i < nodes.length - 1; i++) {
      canvas.drawLine(nodes[i], nodes[i + 1], linePaint);
    }
    for (var i = 0; i < nodes.length; i++) {
      final color = i.isEven ? accent : HelixTheme.amber;
      canvas.drawCircle(
        nodes[i],
        i == 2 ? 8 : 6,
        Paint()..color = color.withValues(alpha: 0.18),
      );
      canvas.drawCircle(nodes[i], i == 2 ? 4 : 3, Paint()..color = color);
    }
  }

  @override
  bool shouldRepaint(covariant _HelixVisualPainter oldDelegate) {
    return oldDelegate.type != type ||
        oldDelegate.accent != accent ||
        oldDelegate.compact != compact;
  }
}
