import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_helix/services/database/helix_database.dart';
import 'package:flutter_helix/services/projects/projects_service.dart';

void main() {
  late HelixDatabase db;
  late ProjectsService svc;

  setUp(() async {
    db = HelixDatabase.forTesting(NativeDatabase.memory());
    await HelixDatabase.overrideForTesting(db);
    svc = ProjectsService.forTesting(db);
  });

  tearDown(() async {
    await HelixDatabase.resetForTesting();
    await db.close();
  });

  test('createProject + watchProjects emits updates', () async {
    final stream = svc.watchProjects();
    final received = <int>[];
    final sub = stream.listen((ps) => received.add(ps.length));
    await svc.createProject(name: 'x');
    await svc.createProject(name: 'y');
    await Future<void>.delayed(const Duration(milliseconds: 50));
    await sub.cancel();
    expect(received.last, 2);
  });

  test('softDelete + undoDelete round-trips', () async {
    final p = await svc.createProject(name: 'x');
    await svc.softDelete(p.id);
    expect((await svc.watchProjects().first), isEmpty);
    await svc.undoDelete(p.id);
    expect((await svc.watchProjects().first).single.id, p.id);
  });

  test('purgeExpired deletes old soft-deleted projects', () async {
    final p = await svc.createProject(name: 'x');
    // Force deletedAt to 10 days ago
    final now = DateTime.now().millisecondsSinceEpoch;
    await (db.update(db.projects)..where((t) => t.id.equals(p.id))).write(
        ProjectsCompanion(
            deletedAt: Value(now - const Duration(days: 10).inMilliseconds)));
    final purged = await svc.purgeExpiredSoftDeletes();
    expect(purged, 1);
  });
}
