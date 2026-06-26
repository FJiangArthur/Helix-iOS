import 'package:flutter/material.dart';

import '../../theme/helix_theme.dart';

class HelixSurface extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double emphasis;
  final Color? accent;
  final bool active;
  final double borderRadius;

  const HelixSurface({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(HelixTheme.spaceLg),
    this.emphasis = 0.35,
    this.accent,
    this.active = false,
    this.borderRadius = HelixTheme.radiusPanel,
  });

  @override
  Widget build(BuildContext context) {
    final fill = HelixTheme.panelFill(emphasis);
    final border = accent == null
        ? HelixTheme.panelBorder(emphasis)
        : accent!.withValues(alpha: active ? 0.42 : 0.22);

    return Container(
      padding: padding,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.lerp(fill, Colors.white, 0.025)!,
            Color.lerp(fill, HelixTheme.background, 0.10)!,
          ],
        ),
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.22),
            blurRadius: active ? 18 : 10,
            offset: const Offset(0, 8),
          ),
          if (active && accent != null)
            BoxShadow(
              color: accent!.withValues(alpha: 0.16),
              blurRadius: 24,
              spreadRadius: 1,
            ),
        ],
      ),
      child: child,
    );
  }
}
