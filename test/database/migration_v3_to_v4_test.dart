import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_helix/services/database/helix_database.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('schema v3 -> v4 migration adds nullable cost columns', () async {
    // Build a fresh in-memory executor whose `setup` callback pre-populates
    // the v3 shape of the relevant tables. When HelixDatabase opens it, Drift
    // will see PRAGMA user_version=3 and run onUpgrade to v4.
    final executor = NativeDatabase.memory(
      setup: (rawDb) {
        rawDb.execute('''
          CREATE TABLE conversations (
            id TEXT NOT NULL PRIMARY KEY,
            started_at INTEGER NOT NULL,
            ended_at INTEGER,
            mode TEXT NOT NULL DEFAULT 'general',
            title TEXT,
            summary TEXT,
            sentiment TEXT,
            tone_analysis TEXT,
            is_processed INTEGER NOT NULL DEFAULT 0,
            silence_ended INTEGER NOT NULL DEFAULT 0,
            source TEXT NOT NULL DEFAULT 'phone',
            audio_file_path TEXT
          );
        ''');
        rawDb.execute('''
          CREATE TABLE conversation_ai_cost_entries (
            id TEXT NOT NULL PRIMARY KEY,
            conversation_id TEXT NOT NULL REFERENCES conversations(id),
            operation_type TEXT NOT NULL,
            provider_id TEXT NOT NULL,
            model_id TEXT NOT NULL,
            input_tokens INTEGER NOT NULL DEFAULT 0,
            output_tokens INTEGER NOT NULL DEFAULT 0,
            cached_input_tokens INTEGER NOT NULL DEFAULT 0,
            audio_input_tokens INTEGER NOT NULL DEFAULT 0,
            audio_output_tokens INTEGER NOT NULL DEFAULT 0,
            cost_usd REAL,
            currency TEXT NOT NULL DEFAULT 'USD',
            status TEXT NOT NULL DEFAULT 'completed',
            started_at INTEGER NOT NULL,
            completed_at INTEGER
          );
        ''');
        rawDb.execute(
          "INSERT INTO conversations(id, started_at, mode, source, is_processed, silence_ended) "
          "VALUES ('legacy-conv', 1700000000000, 'general', 'phone', 0, 0);",
        );
        rawDb.execute(
          "INSERT INTO conversation_ai_cost_entries("
          "id, conversation_id, operation_type, provider_id, model_id, cost_usd, started_at) "
          "VALUES ('legacy-cost', 'legacy-conv', 'answerGeneration', 'openai', 'gpt-5.4', 0.001, 1700000000000);",
        );
        rawDb.execute('PRAGMA user_version = 3;');
      },
    );

    // Open the real database against the same executor → triggers onUpgrade.
    final db = HelixDatabase.testWith(executor);
    addTearDown(db.close);

    // Force a migration by issuing a query.
    final convs = await db.select(db.conversations).get();
    expect(convs.length, 1);
    final legacy = convs.single;
    expect(legacy.id, 'legacy-conv');
    expect(legacy.costSmartUsdMicros, isNull);
    expect(legacy.costLightUsdMicros, isNull);
    expect(legacy.costTranscriptionUsdMicros, isNull);
    expect(legacy.costTotalUsdMicros, isNull);

    final entries = await db.select(db.conversationAiCostEntries).get();
    expect(entries.length, 1);
    expect(entries.single.modelRole, isNull);

    // Round-trip a new conversation with cost columns set.
    await db
        .into(db.conversations)
        .insert(
          ConversationsCompanion.insert(
            id: 'new-conv',
            startedAt: 1700001000000,
            costTotalUsdMicros: const Value(1234),
          ),
        );
    final fetched = await (db.select(db.conversations)
          ..where((c) => c.id.equals('new-conv')))
        .getSingle();
    expect(fetched.costTotalUsdMicros, 1234);
  });
}

