import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

import 'conversation_dao.dart';
import 'facts_dao.dart';
import 'knowledge_dao.dart';
import 'todo_dao.dart';
import 'voice_note_dao.dart';
import 'daily_memory_dao.dart';
import 'search_dao.dart';
import 'project_dao.dart';

part 'helix_database.g.dart';

// ---------------------------------------------------------------------------
// Table definitions
// ---------------------------------------------------------------------------

class Conversations extends Table {
  TextColumn get id => text()();
  IntColumn get startedAt => integer()();
  IntColumn get endedAt => integer().nullable()();
  TextColumn get mode => text().withDefault(
    const Constant('general'),
  )(); // general/interview/passive/proactive
  TextColumn get title => text().nullable()();
  TextColumn get summary => text().nullable()();
  TextColumn get sentiment => text().nullable()();
  TextColumn get toneAnalysis => text().nullable()(); // JSON blob
  BoolColumn get isProcessed => boolean().withDefault(const Constant(false))();
  BoolColumn get silenceEnded => boolean().withDefault(const Constant(false))();
  TextColumn get source =>
      text().withDefault(const Constant('phone'))(); // phone/glasses
  TextColumn get audioFilePath => text().nullable()();
  IntColumn get costSmartUsdMicros => integer().nullable()();
  IntColumn get costLightUsdMicros => integer().nullable()();
  IntColumn get costTranscriptionUsdMicros => integer().nullable()();
  IntColumn get costTotalUsdMicros => integer().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

class ConversationSegments extends Table {
  TextColumn get id => text()();
  TextColumn get conversationId => text().references(Conversations, #id)();
  IntColumn get segmentIndex => integer()();
  TextColumn get text_ => text().named('text')();
  TextColumn get speakerLabel => text().nullable()();
  IntColumn get startedAt => integer()();
  IntColumn get endedAt => integer().nullable()();
  TextColumn get topicId => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

class ConversationAiCostEntries extends Table {
  TextColumn get id => text()();
  TextColumn get conversationId => text().references(Conversations, #id)();
  TextColumn get operationType => text()();
  TextColumn get providerId => text()();
  TextColumn get modelId => text()();
  IntColumn get inputTokens => integer().withDefault(const Constant(0))();
  IntColumn get outputTokens => integer().withDefault(const Constant(0))();
  IntColumn get cachedInputTokens => integer().withDefault(const Constant(0))();
  IntColumn get audioInputTokens => integer().withDefault(const Constant(0))();
  IntColumn get audioOutputTokens => integer().withDefault(const Constant(0))();
  RealColumn get costUsd => real().nullable()();
  TextColumn get currency => text().withDefault(const Constant('USD'))();
  TextColumn get status => text().withDefault(const Constant('completed'))();
  IntColumn get startedAt => integer()();
  IntColumn get completedAt => integer().nullable()();
  TextColumn get modelRole =>
      text().nullable()(); // 'smart' | 'light' | 'transcription'

  @override
  Set<Column> get primaryKey => {id};
}

class Topics extends Table {
  TextColumn get id => text()();
  TextColumn get conversationId => text().references(Conversations, #id)();
  TextColumn get label => text()();
  TextColumn get summary => text().withDefault(const Constant(''))();
  TextColumn get segmentRange => text().withDefault(const Constant(''))();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {id};
}

class Facts extends Table {
  TextColumn get id => text()();
  TextColumn get conversationId => text().nullable()();
  TextColumn get category =>
      text()(); // preference/relationship/habit/opinion/goal/biographical/skill
  TextColumn get content => text()();
  TextColumn get sourceQuote => text().nullable()();
  RealColumn get confidence => real().withDefault(const Constant(0.5))();
  TextColumn get status => text().withDefault(
    const Constant('pending'),
  )(); // pending/confirmed/rejected
  TextColumn get dedupeKey => text().nullable()();
  IntColumn get createdAt => integer()();
  IntColumn get confirmedAt => integer().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

class DailyMemories extends Table {
  TextColumn get id => text()();
  TextColumn get date => text().unique()(); // ISO date string
  TextColumn get narrative => text()();
  TextColumn get themes =>
      text().withDefault(const Constant('[]'))(); // JSON array
  TextColumn get conversationIds =>
      text().withDefault(const Constant('[]'))(); // JSON array
  IntColumn get generatedAt => integer()();

  @override
  Set<Column> get primaryKey => {id};
}

class VoiceNotes extends Table {
  TextColumn get id => text()();
  IntColumn get createdAt => integer()();
  IntColumn get durationMs => integer().withDefault(const Constant(0))();
  TextColumn get transcript => text().nullable()();
  TextColumn get summary => text().nullable()();
  TextColumn get tags =>
      text().withDefault(const Constant('[]'))(); // JSON array

  @override
  Set<Column> get primaryKey => {id};
}

class Todos extends Table {
  TextColumn get id => text()();
  TextColumn get conversationId => text().nullable()();
  TextColumn get content => text()();
  BoolColumn get isCompleted => boolean().withDefault(const Constant(false))();
  IntColumn get dueDate => integer().nullable()();
  IntColumn get createdAt => integer()();
  IntColumn get completedAt => integer().nullable()();
  TextColumn get source =>
      text().withDefault(const Constant('auto'))(); // auto/manual

  @override
  Set<Column> get primaryKey => {id};
}

class BuzzHistoryEntries extends Table {
  TextColumn get id => text()();
  TextColumn get question => text()();
  TextColumn get answer => text()();
  TextColumn get citations =>
      text().withDefault(const Constant('[]'))(); // JSON
  IntColumn get createdAt => integer()();

  @override
  Set<Column> get primaryKey => {id};
}

class KnowledgeEntities extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get type => text()(); // person, company, project, place, topic
  TextColumn get metadata => text().nullable()(); // JSON
  IntColumn get firstSeen => integer()();
  IntColumn get lastSeen => integer()();
  IntColumn get mentionCount => integer().withDefault(const Constant(1))();
  RealColumn get confidence => real().withDefault(const Constant(0.5))();
  TextColumn get source => text()(); // passive, active, manual

  @override
  Set<Column> get primaryKey => {id};
}

class KnowledgeRelationships extends Table {
  TextColumn get id => text()();
  TextColumn get entityAId => text()();
  TextColumn get entityBId => text()();
  TextColumn get relationType => text()();
  TextColumn get description => text().nullable()();
  RealColumn get confidence => real().withDefault(const Constant(0.5))();
  IntColumn get firstSeen => integer()();
  IntColumn get lastSeen => integer()();

  @override
  Set<Column> get primaryKey => {id};
}

class UserProfiles extends Table {
  IntColumn get id => integer().withDefault(const Constant(1))();
  TextColumn get profileJson => text()();
  IntColumn get lastUpdated => integer()();
  IntColumn get version => integer().withDefault(const Constant(1))();

  @override
  Set<Column> get primaryKey => {id};
}

class Projects extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get description => text().nullable()();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();
  IntColumn get deletedAt => integer().nullable()();
  IntColumn get chunkSizeTokens => integer().withDefault(const Constant(800))();
  IntColumn get chunkOverlapTokens =>
      integer().withDefault(const Constant(100))();
  IntColumn get retrievalTopK => integer().withDefault(const Constant(5))();
  RealColumn get retrievalMinSimilarity =>
      real().withDefault(const Constant(0.3))();

  @override
  Set<Column> get primaryKey => {id};
}

class ProjectDocuments extends Table {
  TextColumn get id => text()();
  TextColumn get projectId => text().references(Projects, #id)();
  TextColumn get filename => text()();
  TextColumn get contentType => text()(); // 'pdf' | 'txt'
  IntColumn get byteSize => integer()();
  IntColumn get pageCount => integer().nullable()();
  IntColumn get ingestedAt => integer()();
  IntColumn get deletedAt => integer().nullable()();
  TextColumn get ingestStatus => text()(); // pending|processing|ready|failed
  TextColumn get ingestError => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

class ProjectDocumentChunks extends Table {
  TextColumn get id => text()();
  TextColumn get documentId => text().references(ProjectDocuments, #id)();
  TextColumn get projectId => text().references(Projects, #id)();
  IntColumn get chunkIndex => integer()();
  TextColumn get text_ => text().named('text')();
  IntColumn get tokenCount => integer()();
  IntColumn get pageStart => integer().nullable()();
  IntColumn get pageEnd => integer().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

class ProjectDocumentChunkVectors extends Table {
  TextColumn get chunkId => text().references(ProjectDocumentChunks, #id)();
  BlobColumn get embedding => blob()();
  TextColumn get embeddingModel => text()();

  @override
  Set<Column> get primaryKey => {chunkId};
}

// ---------------------------------------------------------------------------
// Database
// ---------------------------------------------------------------------------

@DriftDatabase(
  tables: [
    Conversations,
    ConversationSegments,
    ConversationAiCostEntries,
    Topics,
    Facts,
    DailyMemories,
    VoiceNotes,
    Todos,
    BuzzHistoryEntries,
    KnowledgeEntities,
    KnowledgeRelationships,
    UserProfiles,
    Projects,
    ProjectDocuments,
    ProjectDocumentChunks,
    ProjectDocumentChunkVectors,
  ],
  daos: [
    ConversationDao,
    FactsDao,
    KnowledgeDao,
    TodoDao,
    VoiceNoteDao,
    DailyMemoryDao,
    SearchDao,
    ProjectDao,
  ],
)
class HelixDatabase extends _$HelixDatabase {
  // Singleton pattern matching the project convention
  static HelixDatabase? _instance;
  static HelixDatabase get instance => _instance ??= HelixDatabase._();

  static Future<void> overrideForTesting(HelixDatabase database) async {
    if (identical(_instance, database)) {
      return;
    }
    await _instance?.close();
    _instance = database;
  }

  static Future<void> resetForTesting() async {
    await _instance?.close();
    _instance = null;
  }

  HelixDatabase._() : super(_openConnection());

  /// For testing
  HelixDatabase.forTesting(super.e);

  /// For testing (alias)
  HelixDatabase.testWith(super.e);

  @override
  int get schemaVersion => 5;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (Migrator m) async {
      await m.createAll();

      // Create FTS5 virtual tables for full-text search
      await customStatement('''
            CREATE VIRTUAL TABLE IF NOT EXISTS conversation_segments_fts
            USING fts5(text, content=conversation_segments, content_rowid=rowid)
          ''');
      await customStatement('''
            CREATE VIRTUAL TABLE IF NOT EXISTS facts_fts
            USING fts5(content, category, content=facts, content_rowid=rowid)
          ''');

      // Triggers to keep FTS indices in sync
      // -- segments
      await customStatement('''
            CREATE TRIGGER IF NOT EXISTS conversation_segments_ai AFTER INSERT ON conversation_segments BEGIN
              INSERT INTO conversation_segments_fts(rowid, text)
              VALUES (new.rowid, new.text);
            END
          ''');
      await customStatement('''
            CREATE TRIGGER IF NOT EXISTS conversation_segments_ad AFTER DELETE ON conversation_segments BEGIN
              INSERT INTO conversation_segments_fts(conversation_segments_fts, rowid, text)
              VALUES ('delete', old.rowid, old.text);
            END
          ''');
      await customStatement('''
            CREATE TRIGGER IF NOT EXISTS conversation_segments_au AFTER UPDATE ON conversation_segments BEGIN
              INSERT INTO conversation_segments_fts(conversation_segments_fts, rowid, text)
              VALUES ('delete', old.rowid, old.text);
              INSERT INTO conversation_segments_fts(rowid, text)
              VALUES (new.rowid, new.text);
            END
          ''');

      // -- facts
      await customStatement('''
            CREATE TRIGGER IF NOT EXISTS facts_ai AFTER INSERT ON facts BEGIN
              INSERT INTO facts_fts(rowid, content, category)
              VALUES (new.rowid, new.content, new.category);
            END
          ''');
      await customStatement('''
            CREATE TRIGGER IF NOT EXISTS facts_ad AFTER DELETE ON facts BEGIN
              INSERT INTO facts_fts(facts_fts, rowid, content, category)
              VALUES ('delete', old.rowid, old.content, old.category);
            END
          ''');
      await customStatement('''
            CREATE TRIGGER IF NOT EXISTS facts_au AFTER UPDATE ON facts BEGIN
              INSERT INTO facts_fts(facts_fts, rowid, content, category)
              VALUES ('delete', old.rowid, old.content, old.category);
              INSERT INTO facts_fts(rowid, content, category)
              VALUES (new.rowid, new.content, new.category);
            END
          ''');

      await customStatement(
          'CREATE INDEX IF NOT EXISTS idx_project_documents_project_deleted '
          'ON project_documents (project_id, deleted_at)');
      await customStatement(
          'CREATE INDEX IF NOT EXISTS idx_project_document_chunks_project '
          'ON project_document_chunks (project_id)');
      await customStatement(
          'CREATE INDEX IF NOT EXISTS idx_project_document_chunks_document '
          'ON project_document_chunks (document_id)');
      await customStatement(
          'CREATE INDEX IF NOT EXISTS idx_projects_deleted '
          'ON projects (deleted_at)');
    },
    onUpgrade: (Migrator m, from, to) async {
      if (from < 2) {
        await m.createTable(conversationAiCostEntries);
      }
      if (from < 3) {
        await m.addColumn(conversations, conversations.audioFilePath);
      }
      if (from < 4) {
        await m.addColumn(conversations, conversations.costSmartUsdMicros);
        await m.addColumn(conversations, conversations.costLightUsdMicros);
        await m.addColumn(
          conversations,
          conversations.costTranscriptionUsdMicros,
        );
        await m.addColumn(conversations, conversations.costTotalUsdMicros);
        await m.addColumn(
          conversationAiCostEntries,
          conversationAiCostEntries.modelRole,
        );
      }
      if (from < 5) {
        await m.createTable(projects);
        await m.createTable(projectDocuments);
        await m.createTable(projectDocumentChunks);
        await m.createTable(projectDocumentChunkVectors);
        await customStatement(
            'CREATE INDEX IF NOT EXISTS idx_project_documents_project_deleted '
            'ON project_documents (project_id, deleted_at)');
        await customStatement(
            'CREATE INDEX IF NOT EXISTS idx_project_document_chunks_project '
            'ON project_document_chunks (project_id)');
        await customStatement(
            'CREATE INDEX IF NOT EXISTS idx_project_document_chunks_document '
            'ON project_document_chunks (document_id)');
        await customStatement(
            'CREATE INDEX IF NOT EXISTS idx_projects_deleted '
            'ON projects (deleted_at)');
      }
    },
  );

  static QueryExecutor _openConnection() {
    return LazyDatabase(() async {
      final dir = await getApplicationDocumentsDirectory();
      final file = File(p.join(dir.path, 'helix_v22.db'));
      return NativeDatabase.createInBackground(file);
    });
  }
}
