import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_helix/theme/helix_type.dart';

void main() {
  group('HelixType — type scale', () {
    test('display style', () {
      final s = HelixType.display();
      expect(s.fontSize, 32);
      expect(s.fontWeight, FontWeight.w600);
      expect(s.height, closeTo(1.15, 0.001));
    });

    test('title1 style', () {
      final s = HelixType.title1();
      expect(s.fontSize, 24);
      expect(s.fontWeight, FontWeight.w600);
      expect(s.height, closeTo(1.20, 0.001));
    });

    test('title2 style', () {
      expect(HelixType.title2().fontSize, 18);
      expect(HelixType.title2().fontWeight, FontWeight.w600);
    });

    test('title3 style', () {
      expect(HelixType.title3().fontSize, 15);
    });

    test('bodyLg style', () {
      expect(HelixType.bodyLg().fontSize, 16);
      expect(HelixType.bodyLg().height, closeTo(1.5, 0.001));
    });

    test('body style', () {
      expect(HelixType.body().fontSize, 14);
    });

    test('bodySm style', () {
      expect(HelixType.bodySm().fontSize, 13);
    });

    test('caption style', () {
      expect(HelixType.caption().fontSize, 12);
    });

    test('label style has tracking', () {
      final s = HelixType.label();
      expect(s.fontSize, 11);
      expect(s.letterSpacing, closeTo(0.6, 0.001));
    });

    test('mono style uses JetBrainsMono', () {
      expect(HelixType.mono().fontFamily, 'JetBrainsMono');
    });

    test('color override propagates', () {
      final s = HelixType.title1(color: const Color(0xFFAABBCC));
      expect(s.color, const Color(0xFFAABBCC));
    });
  });
}
