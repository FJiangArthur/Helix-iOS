import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_helix/services/cost/session_cost_snapshot.dart';
import 'package:flutter_helix/widgets/session_cost_badge.dart';
import 'package:flutter_helix/widgets/session_cost_breakdown_sheet.dart';

void main() {
  Widget wrap(Widget child) =>
      MaterialApp(home: Scaffold(body: Center(child: child)));

  testWidgets('renders Free for zero snapshot', (tester) async {
    final controller = StreamController<SessionCostSnapshot>.broadcast();
    addTearDown(controller.close);
    await tester.pumpWidget(
      wrap(
        SessionCostBadge(
          stream: controller.stream,
          initial: SessionCostSnapshot.zero,
        ),
      ),
    );
    expect(find.text('Free'), findsOneWidget);
  });

  testWidgets('renders formatted dollar amount', (tester) async {
    final controller = StreamController<SessionCostSnapshot>.broadcast();
    addTearDown(controller.close);
    await tester.pumpWidget(
      wrap(
        SessionCostBadge(
          stream: controller.stream,
          initial: const SessionCostSnapshot(smartUsd: 0.005),
        ),
      ),
    );
    expect(find.text('\$0.0050'), findsOneWidget);
  });

  testWidgets('renders summed total', (tester) async {
    final controller = StreamController<SessionCostSnapshot>.broadcast();
    addTearDown(controller.close);
    await tester.pumpWidget(
      wrap(
        SessionCostBadge(
          stream: controller.stream,
          initial: const SessionCostSnapshot(
            smartUsd: 0.018,
            lightUsd: 0.001,
            transcriptionUsd: 0.0044,
          ),
        ),
      ),
    );
    expect(find.text('\$0.0234'), findsOneWidget);
  });

  testWidgets('tap opens breakdown sheet', (tester) async {
    final controller = StreamController<SessionCostSnapshot>.broadcast();
    addTearDown(controller.close);
    await tester.pumpWidget(
      wrap(
        SessionCostBadge(
          stream: controller.stream,
          initial: const SessionCostSnapshot(
            smartUsd: 0.018,
            lightUsd: 0.001,
            transcriptionUsd: 0.0044,
          ),
        ),
      ),
    );
    await tester.tap(find.byType(SessionCostBadge));
    await tester.pumpAndSettle();
    expect(find.byType(SessionCostBreakdownSheet), findsOneWidget);
    expect(find.text('Smart'), findsOneWidget);
    expect(find.text('Light'), findsOneWidget);
    expect(find.text('Transcription'), findsOneWidget);
    expect(find.text('Total'), findsOneWidget);
  });
}
