import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_helix/services/cost/session_cost_snapshot.dart';
import 'package:flutter_helix/widgets/session_cost_breakdown_sheet.dart';

/// Smoke tests around the cost-cell display logic used by
/// `conversation_history_screen.dart`. The full screen requires a database +
/// settings stack so we test the underlying formatting and the shared
/// breakdown sheet here, mirroring `_buildCostChip` and `_showCostBreakdown`.
String formatTotal(int? micros) {
  if (micros == null) return '';
  if (micros == 0) return 'Free';
  return '\$${(micros / 1e6).toStringAsFixed(4)}';
}

void main() {
  group('history cost label', () {
    test('null micros renders empty (label hidden)', () {
      expect(formatTotal(null), '');
    });

    test('zero micros renders Free', () {
      expect(formatTotal(0), 'Free');
    });

    test('23400 micros renders \$0.0234', () {
      expect(formatTotal(23400), '\$0.0234');
    });
  });

  testWidgets('breakdown sheet from per-role micros', (tester) async {
    const smart = 18200;
    const light = 800;
    const trans = 4400;
    final snapshot = SessionCostSnapshot(
      smartUsd: smart / 1e6,
      lightUsd: light / 1e6,
      transcriptionUsd: trans / 1e6,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: SessionCostBreakdownSheet(snapshot: snapshot)),
      ),
    );
    expect(find.text('Smart'), findsOneWidget);
    expect(find.text('Light'), findsOneWidget);
    expect(find.text('Transcription'), findsOneWidget);
    expect(find.text('Total'), findsOneWidget);
    expect(find.text('\$0.0234'), findsOneWidget);
  });
}
