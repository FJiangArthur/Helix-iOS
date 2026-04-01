import 'package:flutter_test/flutter_test.dart';
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

  Future<void> waitForCondition(
    Future<bool> Function() condition, {
    Duration timeout = const Duration(seconds: 2),
    Duration pollInterval = const Duration(milliseconds: 50),
  }) async {
    final deadline = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(deadline)) {
      if (await condition()) return;
      await Future<void>.delayed(pollInterval);
    }
    fail('Timed out waiting for condition after $timeout');
  }

  group('ConversationEngine transcript persistence', () {
    late ConversationEngine engine;

    setUp(() async {
      installPlatformMocks();
      await initTestSettings(
        overrides: {
          'transcriptionBackend': 'openai',
          'autoDetectQuestions': true,
          'autoAnswerQuestions': true,
          'cloudProcessingEnabled': false,
        },
      );
      ConversationEngine.resetTestHooks();
      SettingsManager.instance.assistantProfileId = 'general';
      engine = ConversationEngine.instance;
      await clearConversationData();
      engine.clearHistory();
      engine.stop();
    });

    tearDown(() async {
      engine.clearHistory();
      await clearConversationData();
      removePlatformMocks();
    });

    test(
      'stop saves transcript-only sessions to persisted history and database',
      () async {
        await configureFakeLlm(
          responses: const [
            '{"shouldRespond": false, "question": "", "questionExcerpt": ""}',
            '{"shouldRespond": false, "question": "", "questionExcerpt": ""}',
          ],
        );

        engine.start(source: TranscriptSource.phone);
        engine.onTranscriptionFinalized(
          'We recorded the full conversation even though the websocket failed.',
        );
        engine.onTranscriptionFinalized(
          'The transcript should still be visible after the session stops.',
        );
        await Future<void>.delayed(const Duration(milliseconds: 30));

        expect(engine.history, isEmpty);

        engine.stop();

        await waitForCondition(() async {
          final conversations = await HelixDatabase.instance.conversationDao
              .getAllConversations();
          return conversations.isNotEmpty;
        });

        expect(engine.history, hasLength(1));
        expect(engine.history.single.role, 'user');
        expect(engine.history.single.content, contains('websocket failed'));
        expect(
          engine.history.single.content,
          contains('transcript should still be visible'),
        );

        final conversations = await HelixDatabase.instance.conversationDao
            .getAllConversations();
        expect(conversations, hasLength(1));
        final segments = await HelixDatabase.instance.conversationDao
            .getSegmentsForConversation(conversations.single.id);
        expect(segments.map((segment) => segment.text_).toList(), const [
          'We recorded the full conversation even though the websocket failed.',
          'The transcript should still be visible after the session stops.',
        ]);
      },
    );
  });
}
