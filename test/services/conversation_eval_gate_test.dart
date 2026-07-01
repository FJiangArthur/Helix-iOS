import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_helix/services/conversation_engine.dart';
import 'package:flutter_helix/services/conversation_eval_gate.dart';
import 'package:flutter_helix/services/database/helix_database.dart';
import 'package:flutter_helix/services/passive_listening_service.dart';
import 'package:flutter_helix/services/projects/active_project_controller.dart';
import 'package:flutter_helix/services/projects/project_rag_service.dart';

import '../helpers/test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    installPlatformMocks();
    await initTestSettings();
    await installTestDatabase();
    ActiveProjectController.resetForTesting();
    ProjectRagService.resetForTesting();
    PassiveListeningService.resetInstance();
    ConversationEngine.resetTestHooks();
    ConversationEngine.instance.stop();
    ConversationEngine.instance.clearHistory(force: true);
  });

  tearDown(() async {
    ConversationEngine.instance.stop();
    ConversationEngine.instance.clearHistory(force: true);
    PassiveListeningService.resetInstance();
    ActiveProjectController.resetForTesting();
    ProjectRagService.resetForTesting();
    await HelixDatabase.resetForTesting();
    removePlatformMocks();
  });

  group('ConversationEvalGate', () {
    test(
      'missing live OpenAI key fails and report has required schema',
      () async {
        final report = await ConversationEvalGate(
          apiKey: '',
          gitSha: 'test-sha',
          simulatorUdid: 'test-sim',
        ).run();

        expect(report.overall, 'FAIL');
        expect(report.gitSha, 'test-sha');
        expect(report.simulatorUdid, 'test-sim');
        expect(
          report.checks.map((c) => c.id),
          containsAll(['K1', 'P1', 'P2', 'Q1', 'Q2', 'A1', 'R1', 'W1', 'T1']),
        );

        final hardFailures = report.checks.where((c) => c.failed).toList();
        expect(hardFailures.map((c) => c.id), contains('K1'));
        expect(
          hardFailures.map((c) => c.id),
          containsAll(['Q1', 'Q2', 'A1', 'R1', 'W1', 'T1']),
        );

        final json = report.toJson();
        expect(json['overall'], 'FAIL');
        expect(json['startedAt'], isA<String>());
        expect(json['gitSha'], 'test-sha');
        expect(json['simulatorUdid'], 'test-sim');
        expect(json['latencySummary'], isA<Map<String, Object?>>());
        expect(json['checks'], isA<List<Object?>>());
      },
    );
  });
}
