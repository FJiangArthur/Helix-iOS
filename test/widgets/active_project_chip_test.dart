import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_helix/widgets/active_project_chip.dart';

void main() {
  testWidgets(
      'renders SizedBox.shrink when ActiveProjectController not loaded',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
        home: Scaffold(body: ActiveProjectChip())));
    // Should not throw, just render an invisible no-op.
    expect(find.byType(ActiveProjectChip), findsOneWidget);
    // No chip visible — the subtree is SizedBox.shrink.
    expect(find.text('No project'), findsNothing);
    expect(find.textContaining('Project:'), findsNothing);
  });
}
