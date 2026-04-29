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
}
