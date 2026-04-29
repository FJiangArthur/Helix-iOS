import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_helix/theme/helix_tokens.dart';

void main() {
  group('HelixTokens — light scheme parity with current dark cyan theme', () {
    test('exposes named color tokens', () {
      final t = HelixTokens.light;
      expect(t.bg, isA<Color>());
      expect(t.surface, isA<Color>());
      expect(t.ink, isA<Color>());
      expect(t.accent, isA<Color>());
      expect(t.support, isA<Color>());
      expect(t.success, isA<Color>());
      expect(t.warning, isA<Color>());
      expect(t.danger, isA<Color>());
    });

    test('exposes radius tokens', () {
      expect(HelixTokens.radiusSm, 8);
      expect(HelixTokens.radiusControl, 10); // current cyan theme value
      expect(HelixTokens.radiusPanel, 8);    // current cyan theme value
      expect(HelixTokens.radiusLg, 22);
      expect(HelixTokens.radiusPill, 999);
    });

    test('exposes spacing scale', () {
      expect(HelixTokens.s4, 4);
      expect(HelixTokens.s8, 8);
      expect(HelixTokens.s12, 12);
      expect(HelixTokens.s16, 16);
      expect(HelixTokens.s20, 20);
      expect(HelixTokens.s24, 24);
      expect(HelixTokens.s32, 32);
      expect(HelixTokens.s48, 48);
    });

    test('exposes motion durations', () {
      expect(HelixTokens.durationFast, const Duration(milliseconds: 150));
      expect(HelixTokens.durationMed, const Duration(milliseconds: 250));
      expect(HelixTokens.durationSlow, const Duration(milliseconds: 400));
    });

    test('exposes elevation shadows', () {
      expect(HelixTokens.e1, isA<List<BoxShadow>>());
      expect(HelixTokens.e2, isA<List<BoxShadow>>());
      expect(HelixTokens.e3, isA<List<BoxShadow>>());
      expect(HelixTokens.e1.length, greaterThanOrEqualTo(1));
    });

    test('dark scheme exists (Phase 1: aliased to light, will diverge in Phase 2)', () {
      expect(HelixTokens.dark, isA<ColorTokens>());
    });
  });

  // Phase 1 parity locks: when Phase 2 flips these to Warm Linen, this group
  // intentionally fails — update the expected hexes deliberately at that point
  // so the visual flip is gate-tracked rather than silent drift.
  group('HelixTokens — Phase 1 cyan-preserving values', () {
    test('light.bg matches current dark theme background', () {
      expect(HelixTokens.light.bg, const Color(0xFF090D12));
    });
    test('light.accent matches current cyan', () {
      expect(HelixTokens.light.accent, const Color(0xFF55C7E8));
    });
    test('light.ink matches current text primary', () {
      expect(HelixTokens.light.ink, const Color(0xFFF1F4F7));
    });
    test('accentTint preserves the intentional 0x22 alpha', () {
      // 0x22 alpha = ~13.4% — used as a translucent fill; flattening it
      // would silently change layered surface tints.
      expect(HelixTokens.light.accentTint.a, closeTo(0x22 / 255.0, 0.001));
    });
  });
}
