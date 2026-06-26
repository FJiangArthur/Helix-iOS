import 'package:flutter/material.dart';

import '../../theme/helix_theme.dart';
import 'helix_surface.dart';

class HelixPreviewCard extends StatelessWidget {
  final String label;
  final IconData icon;
  final Widget child;
  final Color accent;
  final EdgeInsetsGeometry padding;

  const HelixPreviewCard({
    super.key,
    required this.label,
    required this.icon,
    required this.child,
    this.accent = HelixTheme.cyan,
    this.padding = const EdgeInsets.all(HelixTheme.spaceMd),
  });

  @override
  Widget build(BuildContext context) {
    return HelixSurface(
      emphasis: 0.18,
      accent: accent,
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 15, color: accent),
              const SizedBox(width: 7),
              Text(
                label.toUpperCase(),
                style: TextStyle(
                  color: accent,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.7,
                ),
              ),
            ],
          ),
          const SizedBox(height: 9),
          child,
        ],
      ),
    );
  }
}
