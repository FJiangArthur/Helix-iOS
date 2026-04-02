import 'package:drift/drift.dart' as drift;
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_helix/services/database/helix_database.dart';
import 'package:flutter_helix/services/history_session_loader.dart';
import 'package:flutter_helix/services/settings_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    installPlatformMocks();
    await SettingsManager.instance.initialize();
  });

  tearDownAll(() async {
    removePlatformMocks();
  });

  Future<void> clearConversationData() async {
    final db = HelixDatabase.instance;
    await db.customStatement('DELETE FROM conversation_ai_cost_entries');
    await db.customStatement('DELETE FROM topics');
    await db.customStatement('DELETE FROM conversation_segments');
    await db.customStatement('DELETE FROM conversations');
  }

  group('HistorySessionLoader', () {
    setUp(() async {
      await installTestDatabase();
      await clearConversationData();
      SettingsManager.instance.assistantProfileId = 'professional';
      SettingsManager.instance.language = 'en';
    });

    tearDown(() async {
      await clearConversationData();
      await resetTestDatabase();
    });

    test('derives review metadata from persisted session transcripts', () async {
      final db = HelixDatabase.instance;
      await db.conversationDao.insertConversation(
        ConversationsCompanion.insert(
          id: 'review-session',
          startedAt: 1700001000000,
          endedAt: const drift.Value(1700001120000),
          mode: const drift.Value('general'),
          title: const drift.Value('Roadmap review'),
          summary: const drift.Value(
            'Review the roadmap, send the follow-up deck, and verify the 120000 budget figure.',
          ),
        ),
      );
      await db.conversationDao.insertSegment(
        ConversationSegmentsCompanion.insert(
          id: 'review-segment-1',
          conversationId: 'review-session',
          segmentIndex: 0,
          text_:
              'Please review the roadmap, send the follow-up deck, and verify the 120000 budget figure.',
          speakerLabel: const drift.Value('other'),
          startedAt: 1700001001000,
        ),
      );
      await db.conversationDao.insertSegment(
        ConversationSegmentsCompanion.insert(
          id: 'review-segment-2',
          conversationId: 'review-session',
          segmentIndex: 1,
          text_: 'I will review the roadmap and confirm the 120000 budget.',
          speakerLabel: const drift.Value('assistant'),
          startedAt: 1700001010000,
        ),
      );

      final sessions = await HistorySessionLoader.loadPersistedSessions(
        favoriteIds: const [],
      );

      expect(sessions, hasLength(1));
      expect(sessions.single.summaryTitle, 'Roadmap review');
      expect(sessions.single.reviewBrief, isNotEmpty);
      expect(sessions.single.reviewSignalCount, greaterThan(0));
      expect(sessions.single.fullTranscript, contains('Even AI'));
    });

    test(
      'loads recorded sessions and preserves proactive mode labeling',
      () async {
        final db = HelixDatabase.instance;
        await db.conversationDao.insertConversation(
          ConversationsCompanion.insert(
            id: 'session-1',
            startedAt: 1700000000000,
            endedAt: const drift.Value(1700000060000),
            mode: const drift.Value('proactive'),
            title: const drift.Value('Recorded strategy session'),
            summary: const drift.Value(
              'Discussed launch questions and answers.',
            ),
          ),
        );
        await db.conversationDao.insertSegment(
          ConversationSegmentsCompanion.insert(
            id: 'segment-1',
            conversationId: 'session-1',
            segmentIndex: 0,
            text_: 'We covered the launch checklist in detail.',
            speakerLabel: const drift.Value('other'),
            startedAt: 1700000001000,
          ),
        );

        final sessions = await HistorySessionLoader.loadPersistedSessions(
          favoriteIds: const ['session-1'],
        );

        expect(sessions, hasLength(1));
        expect(sessions.single.modeLabel, 'Proactive');
        expect(sessions.single.summaryTitle, 'Recorded strategy session');
        expect(sessions.single.searchableText, contains('launch checklist'));
        expect(sessions.single.isFavorite, isTrue);
      },
    );
  });
}
