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
  });
}
