import 'package:flutter/material.dart';

import '../../theme/helix_theme.dart';

enum HelixStatusTone { listening, thinking, ready, offline, error, neutral }

class HelixStatusBadge extends StatelessWidget {
  final String label;
  final HelixStatusTone tone;
  final IconData? icon;

  const HelixStatusBadge({
    super.key,
    required this.label,
    this.tone = HelixStatusTone.neutral,
    this.icon,
  });

  Color get _color {
    return switch (tone) {
      HelixStatusTone.listening => HelixTheme.statusListening,
      HelixStatusTone.thinking => HelixTheme.statusThinking,
      HelixStatusTone.ready => HelixTheme.statusReady,
      HelixStatusTone.offline => HelixTheme.statusOffline,
      HelixStatusTone.error => HelixTheme.error,
      HelixStatusTone.neutral => HelixTheme.textSecondary,
    };
  }

  @override
  Widget build(BuildContext context) {
    final color = _color;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(HelixTheme.radiusPill),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 6),
          ] else ...[
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 7),
          ],
          Text(
            label.toUpperCase(),
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
            ),
          ),
        ],
      ),
    );
  }
}
