import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_helix/screens/conversation_history_screen.dart';
import 'package:flutter_helix/services/conversation_engine.dart';
import 'package:flutter_helix/services/database/helix_database.dart';
import 'package:flutter_helix/services/settings_manager.dart';

import '../helpers/test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> clearConversationData() async {
    final db = HelixDatabase.instance;
    await db.customStatement('DELETE FROM conversation_ai_cost_entries');
    await db.customStatement('DELETE FROM topics');
    await db.customStatement('DELETE FROM conversation_segments');
    await db.customStatement('DELETE FROM conversations');
  }

  Future<void> pumpUntil(
    WidgetTester tester,
    bool Function() condition, {
    Duration timeout = const Duration(seconds: 3),
    Duration step = const Duration(milliseconds: 50),
  }) async {
    final deadline = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(deadline)) {
      await tester.pump(step);
      if (condition()) {
        return;
      }
    }
    fail('Timed out waiting for widget condition after $timeout');
  }

  setUp(() async {
    installPlatformMocks();
    await installTestDatabase();
    await initTestSettings(
      overrides: {
        'transcriptionBackend': 'openai',
        'autoDetectQuestions': true,
        'answerAll': true,
        'cloudProcessingEnabled': false,
      },
    );
    ConversationEngine.resetTestHooks();
    ConversationEngine.instance.clearHistory();
    ConversationEngine.instance.stop();
    SettingsManager.instance
      ..assistantProfileId = 'general'
      ..language = 'en'
      ..sentimentMonitorEnabled = false
      ..entityMemoryEnabled = false
      ..translationEnabled = false;
    await clearConversationData();
  });

  tearDown(() async {
    ConversationEngine.instance.clearHistory();
    await clearConversationData();
    await resetTestDatabase();
    removePlatformMocks();
  });

  testWidgets('history screen reloads persisted transcript sessions after stop', (
    tester,
  ) async {
    final engine = ConversationEngine.instance;
    await configureFakeLlm(
      responses: const [
        '{"shouldRespond": false, "question": "", "questionExcerpt": "", "askedBy": "other"}',
        '{"shouldRespond": true, "question": "What is the rollout plan?", "questionExcerpt": "What is the rollout plan?", "askedBy": "other"}',
        '{"chips": ["Timeline?"], "factCheck": "null"}',
      ],
      streamResponses: const [
        FakeStreamResponse(['The rollout plan is to ship the beta next week.']),
      ],
    );

    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: ConversationHistoryScreen())),
    );
    await tester.pumpAndSettle();

    engine.start(source: TranscriptSource.phone);
    engine.onTranscriptionFinalized(
      'We are discussing the product launch timeline.',
    );
    engine.onTranscriptionFinalized('What is the rollout plan?');

    await pumpUntil(
      tester,
      () => engine.history.any((turn) => turn.role == 'assistant'),
    );

    engine.stop();

    await pumpUntil(
      tester,
      () => find
          .textContaining('We are discussing the product launch timeline.')
          .evaluate()
          .isNotEmpty,
    );

    expect(find.text('1 sessions · 0 fav'), findsOneWidget);
    expect(
      find.textContaining('We are discussing the product launch timeline.'),
      findsAtLeastNWidgets(1),
    );
  });

  testWidgets(
    'history screen shows renamed mode labels for persisted sessions',
    (tester) async {
      final db = HelixDatabase.instance;
      await db.conversationDao.insertConversation(
        ConversationsCompanion.insert(
          id: 'elapsed-session',
          startedAt: 1700003000000,
          endedAt: const drift.Value(1700003060000),
          mode: const drift.Value('proactive'),
          title: const drift.Value('Renamed manual session'),
        ),
      );
      await db.conversationDao.insertSegment(
        ConversationSegmentsCompanion.insert(
          id: 'elapsed-segment-1',
          conversationId: 'elapsed-session',
          segmentIndex: 0,
          text_: 'We are reviewing the launch plan.',
          speakerLabel: const drift.Value('other'),
          startedAt: 1700003000000,
        ),
      );
      await db.conversationDao.insertSegment(
        ConversationSegmentsCompanion.insert(
          id: 'elapsed-segment-2',
          conversationId: 'elapsed-session',
          segmentIndex: 1,
          text_: 'What is the rollout plan?',
          speakerLabel: const drift.Value('other'),
          startedAt: 1700003005000,
        ),
      );

      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: ConversationHistoryScreen())),
      );
      await tester.pumpAndSettle();

      expect(find.text('Answer On-demand'), findsAtLeastNWidgets(1));
    },
  );
}
