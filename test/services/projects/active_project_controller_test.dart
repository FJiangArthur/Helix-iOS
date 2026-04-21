import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_helix/services/projects/active_project_controller.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('default activeProjectId is null', () async {
    final c = await ActiveProjectController.load();
    expect(c.activeProjectId, isNull);
  });

  test('setActive persists and emits on stream', () async {
    final c = await ActiveProjectController.load();
    final received = <String?>[];
    final sub = c.activeProjectStream.listen(received.add);

    await c.setActive('proj-1');
    await Future<void>.delayed(Duration.zero);
    expect(c.activeProjectId, 'proj-1');
    expect(received, contains('proj-1'));

    // Reload from prefs to confirm persistence
    final c2 = await ActiveProjectController.load();
    expect(c2.activeProjectId, 'proj-1');

    await sub.cancel();
  });

  test('setActive(null) clears', () async {
    final c = await ActiveProjectController.load();
    await c.setActive('p');
    await c.setActive(null);
    expect(c.activeProjectId, isNull);
  });
}
