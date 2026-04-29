import 'package:flutter/material.dart';

/// Design tokens for the Helix theme system.
///
/// Phase 1 (this commit): values match the current cool-cyan dark theme so
/// no user-visible change occurs. Phase 2 flips these to Warm Linen.
class ColorTokens {
  const ColorTokens({
    required this.bg,
    required this.bgRaised,
    required this.surface,
    required this.surfaceSunk,
    required this.borderHairline,
    required this.borderStrong,
    required this.ink,
    required this.inkSecondary,
    required this.inkMuted,
    required this.accent,
    required this.accentDeep,
    required this.accentTint,
    required this.support,
    required this.gold,
    required this.success,
    required this.warning,
    required this.danger,
  });

  final Color bg;
  final Color bgRaised;
  final Color surface;
  final Color surfaceSunk;
  final Color borderHairline;
  final Color borderStrong;
  final Color ink;
  final Color inkSecondary;
  final Color inkMuted;
  final Color accent;
  final Color accentDeep;
  final Color accentTint;
  final Color support;
  final Color gold;
  final Color success;
  final Color warning;
  final Color danger;
}

class HelixTokens {
  HelixTokens._();

  /// Light token set. Phase 1: alias of the current dark theme so the visible
  /// surface is unchanged. Phase 2 will replace this with Warm Linen values.
  static const ColorTokens light = ColorTokens(
    bg: Color(0xFF090D12),
    bgRaised: Color(0xFF10161D),
    surface: Color(0xFF151B23),
    surfaceSunk: Color(0xFF0B1117),
    borderHairline: Color(0xFF2B3541),
    borderStrong: Color(0xFF3B4956),
    ink: Color(0xFFF1F4F7),
    inkSecondary: Color(0xFFB1BBC6),
    inkMuted: Color(0xFF7D8996),
    accent: Color(0xFF55C7E8),
    accentDeep: Color(0xFF1C7892),
    accentTint: Color(0x2255C7E8),
    support: Color(0xFF8B96C9),
    gold: Color(0xFFE7AE62),
    success: Color(0xFF8CD6A4),
    warning: Color(0xFFE7AE62),
    danger: Color(0xFFE56C6C),
  );

  /// Dark token set. Phase 1: same as light (single dark theme today).
  static const ColorTokens dark = light;

  // --- Radii ---
  static const double radiusSm = 8;
  static const double radiusControl = 10;
  static const double radiusPanel = 8;
  static const double radiusLg = 22;
  static const double radiusPill = 999;

  // --- Spacing scale ---
  static const double s4 = 4;
  static const double s8 = 8;
  static const double s12 = 12;
  static const double s16 = 16;
  static const double s20 = 20;
  static const double s24 = 24;
  static const double s32 = 32;
  static const double s48 = 48;

  // --- Motion ---
  static const Duration durationFast = Duration(milliseconds: 150);
  static const Duration durationMed = Duration(milliseconds: 250);
  static const Duration durationSlow = Duration(milliseconds: 400);

  // Easing curves (Flutter built-ins, exposed for consistency at call sites).
  static const Curve easeEnter = Curves.easeOutQuint;
  static const Curve easeTransition = Curves.easeInOutCubic;

  // --- Elevation ---
  // Phase 1: black-tinted shadows match existing widgets (GlassCard, GlowButton).
  // Phase 2 will swap the base color to warm brown (0x..3C2814) alongside the
  // Warm Linen palette flip so shadows stay coherent with the new surfaces.
  static const List<BoxShadow> e1 = [
    BoxShadow(
      color: Color(0x0A000000),
      offset: Offset(0, 1),
      blurRadius: 2,
    ),
  ];
  static const List<BoxShadow> e2 = [
    BoxShadow(
      color: Color(0x0F000000),
      offset: Offset(0, 4),
      blurRadius: 12,
    ),
  ];
  static const List<BoxShadow> e3 = [
    BoxShadow(
      color: Color(0x1A000000),
      offset: Offset(0, 12),
      blurRadius: 32,
    ),
  ];

  /// Resolve the token set for the current brightness. In Phase 1, [light]
  /// and [dark] share the same values, so the result is identical regardless
  /// of brightness. Phase 2 forks them when Warm Linen lands.
  static ColorTokens of(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return brightness == Brightness.dark ? dark : light;
  }
}
