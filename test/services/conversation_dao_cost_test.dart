import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_helix/services/database/helix_database.dart';

void main() {
  late HelixDatabase db;

  setUp(() {
    db = HelixDatabase.testWith(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  test('aggregates persisted AI cost by conversation', () async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.conversationDao.insertConversation(
      ConversationsCompanion.insert(
        id: 'conv-1',
        startedAt: now,
        mode: const Value('general'),
        source: const Value('glasses'),
      ),
    );

    await db
        .into(db.conversationAiCostEntries)
        .insert(
          ConversationAiCostEntriesCompanion.insert(
            id: 'cost-1',
            conversationId: 'conv-1',
            operationType: 'questionDetection',
            providerId: 'openai',
            modelId: 'gpt-5.4-mini',
            costUsd: const Value(0.0012),
            startedAt: now,
            completedAt: const Value.absent(),
          ),
        );
    await db
        .into(db.conversationAiCostEntries)
        .insert(
          ConversationAiCostEntriesCompanion.insert(
            id: 'cost-2',
            conversationId: 'conv-1',
            operationType: 'answerGeneration',
            providerId: 'openai',
            modelId: 'gpt-5.4',
            costUsd: const Value(0.0185),
            startedAt: now + 1,
            completedAt: const Value.absent(),
          ),
        );

    expect(
      await db.conversationDao.getTotalAiCostUsd('conv-1'),
      closeTo(0.0197, 0.000001),
    );
  });
}
