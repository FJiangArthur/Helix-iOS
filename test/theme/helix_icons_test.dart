import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:flutter_helix/theme/helix_icons.dart';

void main() {
  group('HelixIcons registry', () {
    test('every concept maps to a non-null PhosphorIconData', () {
      final entries = {
        'listen': HelixIcons.listen,
        'pause': HelixIcons.pause,
        'glasses': HelixIcons.glasses,
        'ai': HelixIcons.ai,
        'chat': HelixIcons.chat,
        'fact': HelixIcons.fact,
        'memory': HelixIcons.memory,
        'todo': HelixIcons.todo,
        'insight': HelixIcons.insight,
        'settings': HelixIcons.settings,
        'home': HelixIcons.home,
        'search': HelixIcons.search,
        'bookmark': HelixIcons.bookmark,
        'book': HelixIcons.book,
        'bluetooth': HelixIcons.bluetooth,
        'battery': HelixIcons.battery,
        'caret': HelixIcons.caret,
        'close': HelixIcons.close,
        'more': HelixIcons.more,
        'play': HelixIcons.play,
        'record': HelixIcons.record,
        'cost': HelixIcons.cost,
        'device': HelixIcons.device,
        'cloud': HelixIcons.cloud,
        'lightning': HelixIcons.lightning,
      };
      for (final entry in entries.entries) {
        expect(entry.value, isA<IconData>(), reason: entry.key);
      }
    });
  });

  group('HelixIcon widget', () {
    testWidgets('renders a PhosphorIcon by default', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: HelixIcon(HelixIcons.listen),
          ),
        ),
      );
      expect(find.byType(PhosphorIcon), findsOneWidget);
    });

    testWidgets('size override applies', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: HelixIcon(HelixIcons.listen, size: 32),
          ),
        ),
      );
      final icon = tester.widget<PhosphorIcon>(find.byType(PhosphorIcon));
      expect(icon.size, 32);
    });

    testWidgets('default useDuotone renders the duotone glyph', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: HelixIcon(HelixIcons.listen),
          ),
        ),
      );
      final icon = tester.widget<PhosphorIcon>(find.byType(PhosphorIcon));
      expect(icon.icon, PhosphorIconsDuotone.microphone,
          reason: 'duotone is the default weight');
    });

    testWidgets('useDuotone: false renders the regular glyph', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: HelixIcon(HelixIcons.listen, useDuotone: false),
          ),
        ),
      );
      final icon = tester.widget<PhosphorIcon>(find.byType(PhosphorIcon));
      expect(icon.icon, PhosphorIconsRegular.microphone);
    });

    testWidgets('color and duotoneTint overrides propagate', (tester) async {
      const ink = Color(0xFF112233);
      const tint = Color(0xFFAABBCC);
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: HelixIcon(
              HelixIcons.listen,
              color: ink,
              duotoneTint: tint,
            ),
          ),
        ),
      );
      final icon = tester.widget<PhosphorIcon>(find.byType(PhosphorIcon));
      expect(icon.color, ink);
      expect(icon.duotoneSecondaryColor, tint);
    });
  });

  // Parity lock — guards against silent drift when a new HelixIcons concept
  // is added without a matching duotone map entry. Adding a new icon would
  // otherwise fall back to the regular weight at render time and no test
  // would notice.
  group('HelixIcons ↔ duotone map parity', () {
    test('every registry entry has a duotone counterpart', () {
      final missing = <IconData>[];
      for (final icon in HelixIcons.all) {
        if (!HelixIcon.duotoneMap.containsKey(icon)) {
          missing.add(icon);
        }
      }
      expect(missing, isEmpty,
          reason: 'HelixIcons.all has ${missing.length} entries with no '
              'matching HelixIcon._duotoneMap key — duotone widget would '
              'silently fall back to regular weight at render time.');
    });

    test('duotone map has no entries beyond the registry', () {
      final extra = <IconData>[];
      for (final key in HelixIcon.duotoneMap.keys) {
        if (!HelixIcons.all.contains(key)) {
          extra.add(key);
        }
      }
      expect(extra, isEmpty,
          reason: 'HelixIcon._duotoneMap has ${extra.length} keys not '
              'present in HelixIcons.all — orphaned mappings.');
    });

    test('registry size matches expected count', () {
      // Phase 1 baseline: 25 semantic concepts. If this number changes,
      // the spec, the registry, and the duotone map should all be updated
      // together.
      expect(HelixIcons.all.length, 25);
    });
  });
}
