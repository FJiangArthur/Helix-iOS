import 'dart:ui';

import 'package:flutter/material.dart';

import '../theme/helix_theme.dart';

class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets? padding;
  final double? borderRadius;
  final Color? borderColor;
  final double opacity;

  const GlassCard({
    super.key,
    required this.child,
    this.padding,
    this.borderRadius,
    this.borderColor,
    this.opacity = 0.15,
  });

  @override
  Widget build(BuildContext context) {
    final radius = borderRadius ?? HelixTheme.radiusPanel;
    final emphasis = (opacity / 0.2).clamp(0.0, 1.0);
    final fill = HelixTheme.panelFill(emphasis);
    final topFill = Color.lerp(
      fill,
      Colors.white,
      0.025,
    )!.withValues(alpha: fill.a);
    final stroke = borderColor ?? HelixTheme.panelBorder(emphasis);

    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          padding: padding ?? const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [topFill, fill],
            ),
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(color: stroke),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.18),
                blurRadius: 10,
                offset: const Offset(0, 6),
              ),
              BoxShadow(
                color: Colors.white.withValues(alpha: 0.02),
                blurRadius: 1,
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}
