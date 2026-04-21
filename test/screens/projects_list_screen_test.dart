import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_helix/screens/projects/projects_list_screen.dart';
import 'package:flutter_helix/services/database/helix_database.dart';
import 'package:flutter_helix/services/projects/projects_service.dart';

/// Tick Drift's watch streams + rebuild the widget tree without using
/// pumpAndSettle (which never returns with live streams).
Future<void> settle(WidgetTester tester,
    {Duration tick = const Duration(milliseconds: 50), int times = 10}) async {
  for (var i = 0; i < times; i++) {
    await tester.runAsync(() async {
      await Future<void>.delayed(tick);
    });
    await tester.pump(tick);
  }
}

void main() {
  late HelixDatabase db;

  setUp(() async {
    db = HelixDatabase.forTesting(NativeDatabase.memory());
    await HelixDatabase.overrideForTesting(db);
    ProjectsService.resetForTesting();
    ProjectsService.forTesting(db);
  });

  tearDown(() async {
    // Drift's stream cancellation schedules a zero-duration Timer via
    // FakeAsync that trips `!timersPending` on teardown. Resetting the
    // singleton (which also closes the db) is fine here — db.close() was
    // already awaited indirectly via resetForTesting.
    await HelixDatabase.resetForTesting();
    ProjectsService.resetForTesting();
  });

  /// Dispose the widget tree and let Drift's stream-cancel Timer fire
  /// before the test body completes. Without this, `!timersPending`
  /// throws at end-of-test.
  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await settle(tester);
  }

  testWidgets('renders empty state when no projects', (tester) async {
    await tester.pumpWidget(const MaterialApp(
        home: Scaffold(body: ProjectsListScreen())));
    await settle(tester);
    expect(find.textContaining('No projects yet'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('creating a project via dialog adds it to the list',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
        home: Scaffold(body: ProjectsListScreen())));
    await settle(tester);

    await tester.tap(find.byIcon(Icons.add));
    await settle(tester);
    expect(find.byType(TextField), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'Q3');
    await settle(tester);

    await tester.tap(find.text('Create'));
    // The dialog's pop + DB insert + stream emission all need time.
    await settle(tester, times: 20);

    expect(find.text('Q3'), findsOneWidget);
    await unmount(tester);
  });
}
