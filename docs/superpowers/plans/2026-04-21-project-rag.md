# Project RAG — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship a per-project document library with semantic retrieval that enriches live auto-answers when a project is active, plus a manage-and-query Projects tab.

**Architecture:** Four new Drift tables (`projects`, `project_documents`, `project_document_chunks`, `project_document_chunk_vectors`) with cosine similarity computed in Dart against in-memory vectors. New services (`ProjectsService`, `DocumentIngestService`, `DocumentEmbeddingStore`, `ProjectRagService`, `ActiveProjectController`) live alongside existing services without modifying Buzz. Single surgical hook in `ConversationEngine._generateResponse` prepends a `PROJECT CONTEXT` block when an active project is set and retrieval returns chunks. New tab appended to `LiveHistoryScreen` with project list / detail / settings / "Ask this project" surfaces.

**Tech Stack:** Flutter/Dart, Drift (SQLite), OpenAI `text-embedding-3-small`, `syncfusion_flutter_pdf` (to add), `file_picker` (to add), existing `LlmService` + `SettingsManager` + `HelixTheme`.

**Spec:** `docs/superpowers/specs/2026-04-21-project-rag-design.md` (commit `c8d4def`)

**Execution strategy:** Depth-first. Each task produces a runnable, testable slice. Tasks 1-4 land the schema and the embedding client. Tasks 5-9 land the service layer. Tasks 10-11 land the `ConversationEngine` hook. Tasks 12-17 land UI. Task 18 is the simulator smoke test.

**Parallelizable slices** (noted at each task):
- Tasks 5 (chunker) and 7 (embedding client wiring) are independent once Task 4 lands.
- Tasks 12 (LiveHistoryScreen 3rd tab) and 15 (HomeScreen chip) are independent once Task 9 lands.
- UI widget tests (Tasks 12-16) can be written in parallel with service tests once APIs are frozen.

---

## Pre-flight

### Task 0: Verify environment and add dependencies

**Files:**
- Modify: `pubspec.yaml`

- [ ] **Step 1: Verify clean git state**

Run: `git status`

Expected: working tree clean or only the approved spec changes. If unclean, stop and resolve.

- [ ] **Step 2: Add dependencies to `pubspec.yaml`**

Find the `dependencies:` block (currently ends after `logger: ^2.0.0`). Add:

```yaml
  # PDF parsing for Project RAG
  syncfusion_flutter_pdf: ^30.1.37

  # Document picker for iOS (Project RAG)
  file_picker: ^10.1.2
```

Place them right after `logger: ^2.0.0`. Do not reorder existing entries.

- [ ] **Step 3: Install and verify**

Run:
```bash
flutter pub get
flutter analyze
```

Expected: Both commit successfully. `flutter analyze` reports 0 errors. Warnings about unused imports from the new packages are fine — we'll consume them in later tasks.

- [ ] **Step 4: Commit**

```bash
git add pubspec.yaml pubspec.lock
git commit -m "chore(projects): add syncfusion_flutter_pdf and file_picker deps"
```

---

## Schema layer

### Task 1: Define Drift tables for projects

**Files:**
- Modify: `lib/services/database/helix_database.dart`

- [ ] **Step 1: Write the failing test**

Create: `test/services/database/project_tables_test.dart`

```dart
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_helix/services/database/helix_database.dart';

void main() {
  late HelixDatabase db;

  setUp(() {
    db = HelixDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  test('can insert and read a project with default tuning values', () async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.into(db.projects).insert(
          ProjectsCompanion.insert(
            id: 'p1',
            name: 'Q3 Review',
            createdAt: now,
            updatedAt: now,
          ),
        );

    final rows = await db.select(db.projects).get();
    expect(rows, hasLength(1));
    expect(rows.single.name, 'Q3 Review');
    expect(rows.single.chunkSizeTokens, 800);
    expect(rows.single.chunkOverlapTokens, 100);
    expect(rows.single.retrievalTopK, 5);
    expect(rows.single.retrievalMinSimilarity, closeTo(0.3, 1e-9));
    expect(rows.single.deletedAt, isNull);
  });

  test('can insert a document, chunk, and chunk vector', () async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.into(db.projects).insert(ProjectsCompanion.insert(
        id: 'p1', name: 'p', createdAt: now, updatedAt: now));
    await db.into(db.projectDocuments).insert(ProjectDocumentsCompanion.insert(
        id: 'd1',
        projectId: 'p1',
        filename: 'f.txt',
        contentType: 'txt',
        byteSize: 10,
        ingestedAt: now,
        ingestStatus: 'ready'));
    await db.into(db.projectDocumentChunks).insert(
        ProjectDocumentChunksCompanion.insert(
            id: 'c1',
            documentId: 'd1',
            projectId: 'p1',
            chunkIndex: 0,
            text: 'hello',
            tokenCount: 1));
    await db.into(db.projectDocumentChunkVectors).insert(
        ProjectDocumentChunkVectorsCompanion.insert(
            chunkId: 'c1',
            embedding: List.filled(1536 * 4, 0),
            embeddingModel: 'text-embedding-3-small'));

    expect((await db.select(db.projectDocuments).get()).single.filename, 'f.txt');
    expect((await db.select(db.projectDocumentChunks).get()).single.text, 'hello');
    expect(
        (await db.select(db.projectDocumentChunkVectors).get()).single.chunkId,
        'c1');
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/services/database/project_tables_test.dart`

Expected: FAIL — `Projects`, `ProjectDocuments`, etc. are undefined.

- [ ] **Step 3: Add table definitions**

In `lib/services/database/helix_database.dart`, after the `UserProfiles` table (line ~206) and before the `// Database` divider, insert:

```dart
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
```

In the `@DriftDatabase` annotation (line ~212), add the four new tables at the end of the `tables:` list:

```dart
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
  ],
)
```

Bump the schema version at line 264 from `4` to `5`.

In the `onUpgrade` block (inside `MigrationStrategy`, line ~326), add a new branch at the end:

```dart
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
```

Also extend the `onCreate` block (after line ~324, inside the existing `onCreate`) to create the same indexes for fresh installs. Append this block to `onCreate` just after the existing `facts_au` trigger statement:

```dart
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
```

- [ ] **Step 4: Regenerate Drift code**

Run:
```bash
dart run build_runner build --delete-conflicting-outputs
```

Expected: Generates updated `helix_database.g.dart` with new table classes (`$ProjectsTable`, `ProjectsCompanion`, `Project`, etc.).

- [ ] **Step 5: Run the test to verify it passes**

Run: `flutter test test/services/database/project_tables_test.dart`

Expected: PASS — all three test cases pass.

- [ ] **Step 6: Run `flutter analyze`**

Run: `flutter analyze`

Expected: 0 errors. The new generated code should not introduce any.

- [ ] **Step 7: Commit**

```bash
git add lib/services/database/helix_database.dart lib/services/database/helix_database.g.dart test/services/database/project_tables_test.dart
git commit -m "feat(projects): add Drift tables for projects, documents, chunks, vectors"
```

---

### Task 2: Write ProjectDao

**Files:**
- Create: `lib/services/database/project_dao.dart`
- Modify: `lib/services/database/helix_database.dart` (register DAO)

- [ ] **Step 1: Write the failing test**

Create: `test/services/database/project_dao_test.dart`

```dart
import 'dart:typed_data';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_helix/services/database/helix_database.dart';

void main() {
  late HelixDatabase db;

  setUp(() {
    db = HelixDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  group('ProjectDao - projects', () {
    test('createProject persists defaults and returns inserted row', () async {
      final p = await db.projectDao.createProject(name: 'Q3', description: 'r');
      expect(p.name, 'Q3');
      expect(p.description, 'r');
      expect(p.chunkSizeTokens, 800);
      expect(p.retrievalTopK, 5);
      expect(p.deletedAt, isNull);
    });

    test('watchActiveProjects excludes soft-deleted', () async {
      final p1 = await db.projectDao.createProject(name: 'a');
      final p2 = await db.projectDao.createProject(name: 'b');
      await db.projectDao.softDeleteProject(p1.id);
      final rows = await db.projectDao.watchActiveProjects().first;
      expect(rows.map((r) => r.id), [p2.id]);
    });

    test('watchRecentlyDeleted includes only soft-deleted within 7 days',
        () async {
      final now = DateTime.now().millisecondsSinceEpoch;
      final p1 = await db.projectDao.createProject(name: 'a');
      final p2 = await db.projectDao.createProject(name: 'b');
      await db.projectDao.softDeleteProject(p1.id);
      // Manually set p2.deleted_at to 10 days ago so purge-scan would remove it
      await (db.update(db.projects)..where((t) => t.id.equals(p2.id))).write(
          ProjectsCompanion(
              deletedAt: Value(now - const Duration(days: 10).inMilliseconds)));
      final rows = await db.projectDao.watchRecentlyDeleted().first;
      expect(rows.map((r) => r.id), [p1.id]);
    });

    test('undoDelete clears deleted_at if within window', () async {
      final p = await db.projectDao.createProject(name: 'a');
      await db.projectDao.softDeleteProject(p.id);
      await db.projectDao.undoDelete(p.id);
      final fresh = await db.projectDao.getProjectById(p.id);
      expect(fresh!.deletedAt, isNull);
    });

    test('purgeExpiredSoftDeletes removes rows older than 7 days and cascades',
        () async {
      final now = DateTime.now().millisecondsSinceEpoch;
      final p = await db.projectDao.createProject(name: 'a');
      // Add a document, chunk, and vector so we can verify cascade
      await db.into(db.projectDocuments).insert(
          ProjectDocumentsCompanion.insert(
              id: 'd1',
              projectId: p.id,
              filename: 'f',
              contentType: 'txt',
              byteSize: 1,
              ingestedAt: now,
              ingestStatus: 'ready'));
      await db.into(db.projectDocumentChunks).insert(
          ProjectDocumentChunksCompanion.insert(
              id: 'c1',
              documentId: 'd1',
              projectId: p.id,
              chunkIndex: 0,
              text: 't',
              tokenCount: 1));
      await db.into(db.projectDocumentChunkVectors).insert(
          ProjectDocumentChunkVectorsCompanion.insert(
              chunkId: 'c1',
              embedding: Uint8List(6144),
              embeddingModel: 'text-embedding-3-small'));

      await (db.update(db.projects)..where((t) => t.id.equals(p.id))).write(
          ProjectsCompanion(
              deletedAt: Value(now - const Duration(days: 8).inMilliseconds)));
      final purged = await db.projectDao.purgeExpiredSoftDeletes();
      expect(purged, 1);
      expect(await db.select(db.projects).get(), isEmpty);
      expect(await db.select(db.projectDocuments).get(), isEmpty);
      expect(await db.select(db.projectDocumentChunks).get(), isEmpty);
      expect(await db.select(db.projectDocumentChunkVectors).get(), isEmpty);
    });
  });

  group('ProjectDao - documents', () {
    test('insertDocument + listDocumentsForProject returns in order', () async {
      final p = await db.projectDao.createProject(name: 'a');
      final d = await db.projectDao.insertDocument(
          projectId: p.id,
          filename: 'f.pdf',
          contentType: 'pdf',
          byteSize: 100);
      final docs = await db.projectDao.listDocumentsForProject(p.id);
      expect(docs, hasLength(1));
      expect(docs.single.id, d.id);
      expect(docs.single.ingestStatus, 'pending');
    });

    test('updateDocumentStatus transitions pending → ready', () async {
      final p = await db.projectDao.createProject(name: 'a');
      final d = await db.projectDao.insertDocument(
          projectId: p.id,
          filename: 'f.txt',
          contentType: 'txt',
          byteSize: 10);
      await db.projectDao
          .updateDocumentStatus(d.id, status: 'ready', pageCount: 3);
      final fresh = await db.projectDao.getDocumentById(d.id);
      expect(fresh!.ingestStatus, 'ready');
      expect(fresh.pageCount, 3);
    });

    test('softDeleteDocument hides from list', () async {
      final p = await db.projectDao.createProject(name: 'a');
      final d = await db.projectDao.insertDocument(
          projectId: p.id,
          filename: 'f.txt',
          contentType: 'txt',
          byteSize: 10);
      await db.projectDao.softDeleteDocument(d.id);
      final docs = await db.projectDao.listDocumentsForProject(p.id);
      expect(docs, isEmpty);
    });

    test('saveChunksAndVectors stores all in one transaction', () async {
      final p = await db.projectDao.createProject(name: 'a');
      final d = await db.projectDao.insertDocument(
          projectId: p.id,
          filename: 'f.txt',
          contentType: 'txt',
          byteSize: 10);
      final vec = Uint8List.fromList(List.generate(6144, (i) => i % 256));
      await db.projectDao.saveChunksAndVectors(
        documentId: d.id,
        projectId: p.id,
        chunks: [
          const ChunkToPersist(
              chunkIndex: 0,
              text: 'hello world',
              tokenCount: 2,
              pageStart: 1,
              pageEnd: 1),
        ],
        vectors: [vec],
        embeddingModel: 'text-embedding-3-small',
      );
      final chunks = await db.projectDao.loadProjectChunksWithVectors(p.id);
      expect(chunks, hasLength(1));
      expect(chunks.single.chunk.text_, 'hello world');
      expect(chunks.single.vector, vec);
    });

    test('loadProjectChunksWithVectors skips chunks whose document is deleted',
        () async {
      final p = await db.projectDao.createProject(name: 'a');
      final d = await db.projectDao.insertDocument(
          projectId: p.id,
          filename: 'f.txt',
          contentType: 'txt',
          byteSize: 10);
      await db.projectDao.saveChunksAndVectors(
        documentId: d.id,
        projectId: p.id,
        chunks: [
          const ChunkToPersist(
              chunkIndex: 0, text: 'x', tokenCount: 1),
        ],
        vectors: [Uint8List(6144)],
        embeddingModel: 'text-embedding-3-small',
      );
      await db.projectDao.softDeleteDocument(d.id);
      final chunks = await db.projectDao.loadProjectChunksWithVectors(p.id);
      expect(chunks, isEmpty);
    });
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/services/database/project_dao_test.dart`

Expected: FAIL — `db.projectDao` undefined.

- [ ] **Step 3: Create the DAO**

Create `lib/services/database/project_dao.dart`:

```dart
// ABOUTME: Project RAG DAO — CRUD for projects, documents, chunks, vectors.
// ABOUTME: Soft delete with 7-day window; hard-delete purge cascades all children.

import 'dart:typed_data';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import 'helix_database.dart';

part 'project_dao.g.dart';

const _softDeleteRetentionDays = 7;
const Uuid _uuid = Uuid();

/// Data-only value used by callers supplying chunks to persist.
/// A plain Dart class (not a Drift companion) so call sites don't need
/// to import drift types.
class ChunkToPersist {
  const ChunkToPersist({
    required this.chunkIndex,
    required this.text,
    required this.tokenCount,
    this.pageStart,
    this.pageEnd,
  });

  final int chunkIndex;
  final String text;
  final int tokenCount;
  final int? pageStart;
  final int? pageEnd;
}

/// Result row for retrieval: chunk row + its raw vector bytes.
class ChunkWithVector {
  const ChunkWithVector({required this.chunk, required this.vector});
  final ProjectDocumentChunk chunk;
  final Uint8List vector;
}

@DriftAccessor(tables: [
  Projects,
  ProjectDocuments,
  ProjectDocumentChunks,
  ProjectDocumentChunkVectors,
])
class ProjectDao extends DatabaseAccessor<HelixDatabase>
    with _$ProjectDaoMixin {
  ProjectDao(super.db);

  // -------- Projects --------

  Future<Project> createProject({required String name, String? description}) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final id = _uuid.v4();
    await into(projects).insert(ProjectsCompanion.insert(
      id: id,
      name: name,
      description: Value(description),
      createdAt: now,
      updatedAt: now,
    ));
    return (await getProjectById(id))!;
  }

  Future<Project?> getProjectById(String id) {
    return (select(projects)..where((p) => p.id.equals(id)))
        .getSingleOrNull();
  }

  Stream<List<Project>> watchActiveProjects() {
    return (select(projects)
          ..where((p) => p.deletedAt.isNull())
          ..orderBy([(p) => OrderingTerm.desc(p.updatedAt)]))
        .watch();
  }

  Stream<List<Project>> watchRecentlyDeleted() {
    final cutoff = DateTime.now()
        .subtract(const Duration(days: _softDeleteRetentionDays))
        .millisecondsSinceEpoch;
    return (select(projects)
          ..where((p) =>
              p.deletedAt.isNotNull() & p.deletedAt.isBiggerThanValue(cutoff))
          ..orderBy([(p) => OrderingTerm.desc(p.deletedAt)]))
        .watch();
  }

  Future<void> updateProject({
    required String id,
    String? name,
    String? description,
    int? chunkSizeTokens,
    int? chunkOverlapTokens,
    int? retrievalTopK,
    double? retrievalMinSimilarity,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await (update(projects)..where((p) => p.id.equals(id))).write(
      ProjectsCompanion(
        name: name == null ? const Value.absent() : Value(name),
        description:
            description == null ? const Value.absent() : Value(description),
        chunkSizeTokens: chunkSizeTokens == null
            ? const Value.absent()
            : Value(chunkSizeTokens),
        chunkOverlapTokens: chunkOverlapTokens == null
            ? const Value.absent()
            : Value(chunkOverlapTokens),
        retrievalTopK:
            retrievalTopK == null ? const Value.absent() : Value(retrievalTopK),
        retrievalMinSimilarity: retrievalMinSimilarity == null
            ? const Value.absent()
            : Value(retrievalMinSimilarity),
        updatedAt: Value(now),
      ),
    );
  }

  Future<void> softDeleteProject(String id) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await (update(projects)..where((p) => p.id.equals(id)))
        .write(ProjectsCompanion(deletedAt: Value(now)));
  }

  Future<void> undoDelete(String id) async {
    await (update(projects)..where((p) => p.id.equals(id)))
        .write(const ProjectsCompanion(deletedAt: Value(null)));
  }

  /// Hard-delete projects whose deletedAt is older than retention window.
  /// Returns count of purged projects. Cascades to documents/chunks/vectors.
  Future<int> purgeExpiredSoftDeletes() async {
    final cutoff = DateTime.now()
        .subtract(const Duration(days: _softDeleteRetentionDays))
        .millisecondsSinceEpoch;
    return transaction(() async {
      final stale = await (select(projects)
            ..where((p) =>
                p.deletedAt.isNotNull() &
                p.deletedAt.isSmallerOrEqualValue(cutoff)))
          .get();
      for (final p in stale) {
        // Manually cascade because Drift's references don't auto-cascade.
        await (delete(projectDocumentChunkVectors)
              ..where((v) => v.chunkId.isInQuery(
                  selectOnly(projectDocumentChunks)
                    ..addColumns([projectDocumentChunks.id])
                    ..where(projectDocumentChunks.projectId.equals(p.id)))))
            .go();
        await (delete(projectDocumentChunks)
              ..where((c) => c.projectId.equals(p.id)))
            .go();
        await (delete(projectDocuments)
              ..where((d) => d.projectId.equals(p.id)))
            .go();
        await (delete(projects)..where((r) => r.id.equals(p.id))).go();
      }
      return stale.length;
    });
  }

  // -------- Documents --------

  Future<ProjectDocument> insertDocument({
    required String projectId,
    required String filename,
    required String contentType,
    required int byteSize,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final id = _uuid.v4();
    await into(projectDocuments).insert(ProjectDocumentsCompanion.insert(
      id: id,
      projectId: projectId,
      filename: filename,
      contentType: contentType,
      byteSize: byteSize,
      ingestedAt: now,
      ingestStatus: 'pending',
    ));
    return (await getDocumentById(id))!;
  }

  Future<ProjectDocument?> getDocumentById(String id) {
    return (select(projectDocuments)..where((d) => d.id.equals(id)))
        .getSingleOrNull();
  }

  Future<List<ProjectDocument>> listDocumentsForProject(String projectId) {
    return (select(projectDocuments)
          ..where((d) =>
              d.projectId.equals(projectId) & d.deletedAt.isNull())
          ..orderBy([(d) => OrderingTerm.desc(d.ingestedAt)]))
        .get();
  }

  Stream<List<ProjectDocument>> watchDocumentsForProject(String projectId) {
    return (select(projectDocuments)
          ..where((d) =>
              d.projectId.equals(projectId) & d.deletedAt.isNull())
          ..orderBy([(d) => OrderingTerm.desc(d.ingestedAt)]))
        .watch();
  }

  Future<void> updateDocumentStatus(
    String id, {
    required String status,
    String? error,
    int? pageCount,
  }) async {
    final truncatedError =
        error != null && error.length > 500 ? error.substring(0, 500) : error;
    await (update(projectDocuments)..where((d) => d.id.equals(id))).write(
      ProjectDocumentsCompanion(
        ingestStatus: Value(status),
        ingestError:
            error == null ? const Value.absent() : Value(truncatedError),
        pageCount:
            pageCount == null ? const Value.absent() : Value(pageCount),
      ),
    );
  }

  Future<void> softDeleteDocument(String id) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await (update(projectDocuments)..where((d) => d.id.equals(id)))
        .write(ProjectDocumentsCompanion(deletedAt: Value(now)));
  }

  Future<void> renameDocument(String id, String newFilename) async {
    await (update(projectDocuments)..where((d) => d.id.equals(id)))
        .write(ProjectDocumentsCompanion(filename: Value(newFilename)));
  }

  // -------- Chunks + vectors --------

  /// Persists chunks + matching vectors atomically for one document.
  /// `chunks` and `vectors` must be equal length and correspond by index.
  Future<void> saveChunksAndVectors({
    required String documentId,
    required String projectId,
    required List<ChunkToPersist> chunks,
    required List<Uint8List> vectors,
    required String embeddingModel,
  }) async {
    if (chunks.length != vectors.length) {
      throw ArgumentError(
          'chunks (${chunks.length}) and vectors (${vectors.length}) '
          'must be equal length');
    }
    await transaction(() async {
      // Wipe any pre-existing chunks/vectors for this document (retry path).
      await (delete(projectDocumentChunkVectors)
            ..where((v) => v.chunkId.isInQuery(
                selectOnly(projectDocumentChunks)
                  ..addColumns([projectDocumentChunks.id])
                  ..where(projectDocumentChunks.documentId.equals(documentId)))))
          .go();
      await (delete(projectDocumentChunks)
            ..where((c) => c.documentId.equals(documentId)))
          .go();

      for (var i = 0; i < chunks.length; i++) {
        final chunkId = _uuid.v4();
        final c = chunks[i];
        await into(projectDocumentChunks).insert(
            ProjectDocumentChunksCompanion.insert(
                id: chunkId,
                documentId: documentId,
                projectId: projectId,
                chunkIndex: c.chunkIndex,
                text_: c.text,
                tokenCount: c.tokenCount,
                pageStart: Value(c.pageStart),
                pageEnd: Value(c.pageEnd)));
        await into(projectDocumentChunkVectors).insert(
            ProjectDocumentChunkVectorsCompanion.insert(
                chunkId: chunkId,
                embedding: vectors[i],
                embeddingModel: embeddingModel));
      }
    });
  }

  /// Loads all chunks + vectors for non-deleted documents in a project.
  Future<List<ChunkWithVector>> loadProjectChunksWithVectors(
      String projectId) async {
    final query = select(projectDocumentChunks).join([
      innerJoin(
          projectDocumentChunkVectors,
          projectDocumentChunkVectors.chunkId
              .equalsExp(projectDocumentChunks.id)),
      innerJoin(
          projectDocuments,
          projectDocuments.id.equalsExp(projectDocumentChunks.documentId)),
    ])
      ..where(projectDocumentChunks.projectId.equals(projectId) &
          projectDocuments.deletedAt.isNull());
    final rows = await query.get();
    return [
      for (final row in rows)
        ChunkWithVector(
          chunk: row.readTable(projectDocumentChunks),
          vector: row.readTable(projectDocumentChunkVectors).embedding,
        )
    ];
  }
}
```

- [ ] **Step 4: Register the DAO**

In `lib/services/database/helix_database.dart`:

Add `import 'project_dao.dart';` with the other DAO imports (after line 14).

In the `@DriftDatabase` annotation, add `ProjectDao` to the `daos:` list:

```dart
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
```

- [ ] **Step 5: Regenerate code**

```bash
dart run build_runner build --delete-conflicting-outputs
```

- [ ] **Step 6: Run the tests**

```bash
flutter test test/services/database/project_dao_test.dart
```

Expected: all tests PASS.

- [ ] **Step 7: Run full analyze**

```bash
flutter analyze
```

Expected: 0 errors.

- [ ] **Step 8: Commit**

```bash
git add lib/services/database/project_dao.dart lib/services/database/project_dao.g.dart lib/services/database/helix_database.dart lib/services/database/helix_database.g.dart test/services/database/project_dao_test.dart
git commit -m "feat(projects): add ProjectDao with CRUD, soft delete, purge, chunks/vectors"
```

---

## Embedding + chunking primitives

### Task 3: Chunker with recursive splitter

**Files:**
- Create: `lib/services/projects/document_chunker.dart`
- Create: `test/services/projects/document_chunker_test.dart`

- [ ] **Step 1: Write the failing tests**

Create `test/services/projects/document_chunker_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_helix/services/projects/document_chunker.dart';

void main() {
  group('DocumentChunker', () {
    const opts = ChunkOptions(targetTokens: 20, overlapTokens: 4);

    test('empty input produces no chunks', () {
      expect(DocumentChunker.chunk('', opts), isEmpty);
    });

    test('whitespace-only input produces no chunks', () {
      expect(DocumentChunker.chunk('   \n\n  ', opts), isEmpty);
    });

    test('short input fits in one chunk', () {
      final out = DocumentChunker.chunk('Hello world.', opts);
      expect(out, hasLength(1));
      expect(out.single.text, 'Hello world.');
      expect(out.single.chunkIndex, 0);
    });

    test('paragraph longer than target splits by sentence', () {
      final text =
          'Sentence one is here. Sentence two is also here. Sentence three closes.';
      final out = DocumentChunker.chunk(
          text, const ChunkOptions(targetTokens: 6, overlapTokens: 0));
      expect(out.length, greaterThan(1));
      final joined = out.map((c) => c.text).join(' ');
      expect(joined, contains('Sentence one'));
      expect(joined, contains('Sentence three closes'));
    });

    test('overlap copies trailing tokens from previous chunk', () {
      final text = List.generate(40, (i) => 'word$i').join(' ');
      final out = DocumentChunker.chunk(
          text, const ChunkOptions(targetTokens: 10, overlapTokens: 3));
      expect(out.length, greaterThan(1));
      // Second chunk should start with some of the tail of the first.
      final firstTail = out[0].text.split(' ').reversed.take(3).toList().reversed.join(' ');
      expect(out[1].text.startsWith(firstTail.split(' ').first), isTrue);
    });

    test('multi-paragraph input preserves paragraph boundaries when possible',
        () {
      final text = 'Paragraph one line.\n\nParagraph two line.';
      final out = DocumentChunker.chunk(
          text, const ChunkOptions(targetTokens: 100, overlapTokens: 0));
      // Two paragraphs, each small, fit in one chunk (joined with blank line).
      expect(out, hasLength(1));
    });

    test('approximate token count uses 4-chars-per-token rule', () {
      expect(DocumentChunker.approximateTokenCount(''), 0);
      expect(DocumentChunker.approximateTokenCount('a'), 1);
      expect(DocumentChunker.approximateTokenCount('abcd'), 1);
      expect(DocumentChunker.approximateTokenCount('abcde'), 2);
      expect(DocumentChunker.approximateTokenCount('a' * 400), 100);
    });

    test('chunkIndex is monotonically increasing from zero', () {
      final text = List.generate(200, (i) => 'w$i').join(' ');
      final out = DocumentChunker.chunk(
          text, const ChunkOptions(targetTokens: 20, overlapTokens: 2));
      for (var i = 0; i < out.length; i++) {
        expect(out[i].chunkIndex, i);
      }
    });
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

```bash
flutter test test/services/projects/document_chunker_test.dart
```

Expected: FAIL — import can't be resolved.

- [ ] **Step 3: Write the chunker**

Create `lib/services/projects/document_chunker.dart`:

```dart
// ABOUTME: Recursive paragraph/sentence text splitter with configurable
// ABOUTME: target token size and overlap. Uses 4-chars-per-token approximation.

class ChunkOptions {
  const ChunkOptions({required this.targetTokens, required this.overlapTokens});
  final int targetTokens;
  final int overlapTokens;
}

class ChunkResult {
  const ChunkResult({
    required this.chunkIndex,
    required this.text,
    required this.tokenCount,
    this.pageStart,
    this.pageEnd,
  });
  final int chunkIndex;
  final String text;
  final int tokenCount;
  final int? pageStart;
  final int? pageEnd;
}

class DocumentChunker {
  /// Approximate OpenAI tiktoken count: 1 token ~= 4 chars.
  /// Always rounds up for a non-empty string so "a" counts as 1 token.
  static int approximateTokenCount(String s) {
    if (s.isEmpty) return 0;
    return ((s.length + 3) ~/ 4);
  }

  /// Split [text] into chunks. Preserves paragraphs (`\n\n`) as primary
  /// boundaries; falls back to sentence boundaries (`. ` / `! ` / `? `) when
  /// a paragraph exceeds the target size.
  static List<ChunkResult> chunk(String text, ChunkOptions opts) {
    if (text.trim().isEmpty) return [];
    final paragraphs = _splitParagraphs(text);

    // Expand paragraphs that exceed target into their sentences.
    final units = <String>[];
    for (final p in paragraphs) {
      if (approximateTokenCount(p) <= opts.targetTokens) {
        units.add(p);
      } else {
        units.addAll(_splitSentences(p));
      }
    }

    // Greedy pack: append units into a chunk until adding the next would
    // exceed target. Then emit, carry last [overlapTokens] worth of words
    // forward into the next chunk.
    final out = <ChunkResult>[];
    final buffer = StringBuffer();
    int bufferTokens = 0;
    int idx = 0;

    void flush() {
      final trimmed = buffer.toString().trim();
      if (trimmed.isNotEmpty) {
        out.add(ChunkResult(
          chunkIndex: idx++,
          text: trimmed,
          tokenCount: approximateTokenCount(trimmed),
        ));
      }
      buffer.clear();
      bufferTokens = 0;
    }

    String overlapTail() {
      if (opts.overlapTokens <= 0) return '';
      final words = buffer.toString().trim().split(RegExp(r'\s+'));
      final tailWordCount = opts.overlapTokens; // tokens ~= words, good enough
      if (tailWordCount >= words.length) return buffer.toString().trim();
      return words.sublist(words.length - tailWordCount).join(' ');
    }

    for (final unit in units) {
      final unitTokens = approximateTokenCount(unit);
      if (bufferTokens == 0) {
        buffer.write(unit);
        bufferTokens = unitTokens;
        continue;
      }
      if (bufferTokens + unitTokens <= opts.targetTokens) {
        buffer.write('\n\n');
        buffer.write(unit);
        bufferTokens += unitTokens;
      } else {
        final tail = overlapTail();
        flush();
        if (tail.isNotEmpty) {
          buffer.write(tail);
          buffer.write(' ');
          bufferTokens += approximateTokenCount(tail);
        }
        buffer.write(unit);
        bufferTokens += unitTokens;
      }
    }
    flush();
    return out;
  }

  static List<String> _splitParagraphs(String text) {
    return text
        .split(RegExp(r'\n\s*\n'))
        .map((p) => p.trim())
        .where((p) => p.isNotEmpty)
        .toList();
  }

  static List<String> _splitSentences(String text) {
    // Split on sentence-terminating punctuation followed by whitespace.
    // Keep the terminator with the preceding sentence.
    final parts = <String>[];
    final pattern = RegExp(r'(?<=[.!?])\s+');
    for (final piece in text.split(pattern)) {
      final t = piece.trim();
      if (t.isNotEmpty) parts.add(t);
    }
    return parts;
  }
}
```

- [ ] **Step 4: Run tests**

```bash
flutter test test/services/projects/document_chunker_test.dart
```

Expected: all PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/services/projects/document_chunker.dart test/services/projects/document_chunker_test.dart
git commit -m "feat(projects): add recursive paragraph/sentence chunker"
```

---

### Task 4: Cosine similarity + Float32 BLOB conversion helpers

**Files:**
- Create: `lib/services/projects/embedding_math.dart`
- Create: `test/services/projects/embedding_math_test.dart`

- [ ] **Step 1: Write the failing tests**

Create `test/services/projects/embedding_math_test.dart`:

```dart
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_helix/services/projects/embedding_math.dart';

void main() {
  group('EmbeddingMath', () {
    test('encode/decode round-trips', () {
      final src = Float32List.fromList([1.0, -2.5, 3.25, 0.0]);
      final blob = EmbeddingMath.encodeVector(src);
      expect(blob.lengthInBytes, src.length * 4);
      final round = EmbeddingMath.decodeVector(blob);
      expect(round.length, src.length);
      for (var i = 0; i < src.length; i++) {
        expect(round[i], src[i]);
      }
    });

    test('cosine similarity identical vectors = 1.0', () {
      final a = Float32List.fromList([1, 0, 0]);
      final b = Float32List.fromList([1, 0, 0]);
      expect(EmbeddingMath.cosineSimilarity(a, b), closeTo(1.0, 1e-6));
    });

    test('cosine similarity orthogonal = 0', () {
      final a = Float32List.fromList([1, 0, 0]);
      final b = Float32List.fromList([0, 1, 0]);
      expect(EmbeddingMath.cosineSimilarity(a, b), closeTo(0.0, 1e-6));
    });

    test('cosine similarity opposite = -1', () {
      final a = Float32List.fromList([1, 0]);
      final b = Float32List.fromList([-1, 0]);
      expect(EmbeddingMath.cosineSimilarity(a, b), closeTo(-1.0, 1e-6));
    });

    test('cosine of zero vector is 0 (safe divide)', () {
      final a = Float32List.fromList([0, 0, 0]);
      final b = Float32List.fromList([1, 2, 3]);
      expect(EmbeddingMath.cosineSimilarity(a, b), 0.0);
    });

    test('throws when dimensions mismatch', () {
      final a = Float32List.fromList([1, 2]);
      final b = Float32List.fromList([1, 2, 3]);
      expect(() => EmbeddingMath.cosineSimilarity(a, b),
          throwsA(isA<ArgumentError>()));
    });
  });
}
```

- [ ] **Step 2: Run tests to verify failure**

```bash
flutter test test/services/projects/embedding_math_test.dart
```

Expected: FAIL — file missing.

- [ ] **Step 3: Write the helper**

Create `lib/services/projects/embedding_math.dart`:

```dart
// ABOUTME: Float32 vector encode/decode and cosine similarity for Project RAG.
// ABOUTME: Stored as little-endian byte blobs; decode returns Float32List view.

import 'dart:math' as math;
import 'dart:typed_data';

class EmbeddingMath {
  /// Encode a Float32List as a Uint8List blob for BLOB storage.
  /// Host-endian; we always encode and decode on-device so a single byte
  /// order is consistent across reads/writes.
  static Uint8List encodeVector(Float32List v) {
    return Uint8List.view(v.buffer, v.offsetInBytes, v.lengthInBytes);
  }

  /// Decode a BLOB back to Float32List. Always copies because the BLOB
  /// returned from Drift may not be aligned for Float32.
  static Float32List decodeVector(Uint8List blob) {
    if (blob.lengthInBytes % 4 != 0) {
      throw ArgumentError(
          'blob length ${blob.lengthInBytes} is not a multiple of 4');
    }
    final copy = Float32List(blob.lengthInBytes ~/ 4);
    final byteView = Uint8List.view(copy.buffer);
    byteView.setRange(0, blob.lengthInBytes, blob);
    return copy;
  }

  /// Cosine similarity: dot(a,b) / (|a| * |b|). Returns 0 for zero vectors.
  static double cosineSimilarity(Float32List a, Float32List b) {
    if (a.length != b.length) {
      throw ArgumentError('length mismatch: ${a.length} vs ${b.length}');
    }
    double dot = 0;
    double na = 0;
    double nb = 0;
    for (var i = 0; i < a.length; i++) {
      final ai = a[i];
      final bi = b[i];
      dot += ai * bi;
      na += ai * ai;
      nb += bi * bi;
    }
    if (na == 0 || nb == 0) return 0.0;
    return dot / (math.sqrt(na) * math.sqrt(nb));
  }
}
```

- [ ] **Step 4: Run tests**

```bash
flutter test test/services/projects/embedding_math_test.dart
```

Expected: all PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/services/projects/embedding_math.dart test/services/projects/embedding_math_test.dart
git commit -m "feat(projects): add vector encode/decode + cosine similarity helpers"
```

---

### Task 5: OpenAI embeddings client

**Files:**
- Create: `lib/services/projects/openai_embeddings_client.dart`
- Create: `test/services/projects/openai_embeddings_client_test.dart`

This is the only place that talks to OpenAI's `/v1/embeddings` endpoint. It takes raw strings and returns Float32Lists. It's abstracted behind an interface so tests can inject a fake.

- [ ] **Step 1: Write the failing test**

Create `test/services/projects/openai_embeddings_client_test.dart`:

```dart
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_helix/services/projects/openai_embeddings_client.dart';

void main() {
  group('OpenAiEmbeddingsClient', () {
    test('posts inputs and parses embeddings into Float32Lists', () async {
      http.BaseRequest? captured;
      final mock = _MockClient((req) async {
        captured = req;
        final body = jsonEncode({
          'data': [
            {'embedding': [0.1, 0.2, 0.3]},
            {'embedding': [0.4, 0.5, 0.6]},
          ],
          'usage': {'prompt_tokens': 42, 'total_tokens': 42},
        });
        return http.Response(body, 200,
            headers: {'content-type': 'application/json'});
      });

      final client = OpenAiEmbeddingsClient(
          apiKey: 'sk-test',
          httpClient: mock,
          model: 'text-embedding-3-small');

      final result = await client.embedBatch(['a', 'b']);
      expect(result.vectors, hasLength(2));
      expect(result.vectors.first, isA<Float32List>());
      expect(result.vectors.first[0], closeTo(0.1, 1e-6));
      expect(result.vectors.last[2], closeTo(0.6, 1e-6));
      expect(result.promptTokens, 42);
      expect(captured!.url.toString(),
          'https://api.openai.com/v1/embeddings');
      expect(captured!.method, 'POST');
    });

    test('throws EmbeddingApiException on non-2xx', () async {
      final mock = _MockClient((_) async =>
          http.Response('{"error":{"message":"bad"}}', 401));
      final client = OpenAiEmbeddingsClient(
          apiKey: 'sk-x', httpClient: mock, model: 'text-embedding-3-small');
      expect(() => client.embedBatch(['a']),
          throwsA(isA<EmbeddingApiException>()));
    });

    test('throws if inputs is empty', () async {
      final client = OpenAiEmbeddingsClient(
          apiKey: 'sk-x', model: 'text-embedding-3-small');
      expect(() => client.embedBatch(const []),
          throwsA(isA<ArgumentError>()));
    });
  });
}

class _MockClient extends http.BaseClient {
  _MockClient(this._handler);
  final Future<http.Response> Function(http.BaseRequest) _handler;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    // Read the body so assertions can inspect it if needed later.
    await request.finalize().toBytes();
    final resp = await _handler(request);
    return http.StreamedResponse(
      Stream.value(resp.bodyBytes),
      resp.statusCode,
      headers: resp.headers,
      request: request,
    );
  }
}
```

- [ ] **Step 2: Run tests**

```bash
flutter test test/services/projects/openai_embeddings_client_test.dart
```

Expected: FAIL — missing file.

- [ ] **Step 3: Write the client**

Create `lib/services/projects/openai_embeddings_client.dart`:

```dart
// ABOUTME: Minimal OpenAI /v1/embeddings client for Project RAG.
// ABOUTME: Batch-embed inputs, returns Float32Lists + usage metadata.

import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

class EmbeddingApiException implements Exception {
  EmbeddingApiException(this.statusCode, this.message);
  final int statusCode;
  final String message;
  @override
  String toString() => 'EmbeddingApiException($statusCode): $message';
}

class EmbeddingBatchResult {
  const EmbeddingBatchResult({
    required this.vectors,
    required this.promptTokens,
  });
  final List<Float32List> vectors;
  final int promptTokens;
}

class OpenAiEmbeddingsClient {
  OpenAiEmbeddingsClient({
    required this.apiKey,
    required this.model,
    http.Client? httpClient,
    this.baseUrl = 'https://api.openai.com/v1',
  }) : _http = httpClient ?? http.Client();

  final String apiKey;
  final String model;
  final String baseUrl;
  final http.Client _http;

  Future<EmbeddingBatchResult> embedBatch(List<String> inputs) async {
    if (inputs.isEmpty) {
      throw ArgumentError('inputs must be non-empty');
    }
    final uri = Uri.parse('$baseUrl/embeddings');
    final body = jsonEncode({'model': model, 'input': inputs});
    final resp = await _http.post(uri,
        headers: {
          'Authorization': 'Bearer $apiKey',
          'Content-Type': 'application/json',
        },
        body: body);
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw EmbeddingApiException(resp.statusCode, resp.body);
    }
    final decoded = jsonDecode(resp.body) as Map<String, dynamic>;
    final data = (decoded['data'] as List).cast<Map<String, dynamic>>();
    final vectors = <Float32List>[];
    for (final entry in data) {
      final emb = (entry['embedding'] as List).cast<num>();
      final v = Float32List(emb.length);
      for (var i = 0; i < emb.length; i++) {
        v[i] = emb[i].toDouble();
      }
      vectors.add(v);
    }
    final usage = decoded['usage'] as Map<String, dynamic>?;
    return EmbeddingBatchResult(
      vectors: vectors,
      promptTokens: (usage?['prompt_tokens'] as num?)?.toInt() ?? 0,
    );
  }

  /// Single-input convenience.
  Future<Float32List> embed(String input) async {
    final result = await embedBatch([input]);
    return result.vectors.single;
  }

  void close() => _http.close();
}
```

- [ ] **Step 4: Run tests**

```bash
flutter test test/services/projects/openai_embeddings_client_test.dart
```

Expected: all PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/services/projects/openai_embeddings_client.dart test/services/projects/openai_embeddings_client_test.dart
git commit -m "feat(projects): add OpenAI embeddings client"
```

---

## Service layer

### Task 6: ProjectsService singleton

**Files:**
- Create: `lib/services/projects/projects_service.dart`
- Create: `test/services/projects/projects_service_test.dart`

Thin wrapper around `ProjectDao` for service-layer callers. Adds singleton + purge-on-launch hook.

- [ ] **Step 1: Write the failing test**

Create `test/services/projects/projects_service_test.dart`:

```dart
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
```

- [ ] **Step 2: Run tests to verify failure**

```bash
flutter test test/services/projects/projects_service_test.dart
```

Expected: FAIL — file missing.

- [ ] **Step 3: Write the service**

Create `lib/services/projects/projects_service.dart`:

```dart
// ABOUTME: Singleton facade over ProjectDao for service-layer callers.
// ABOUTME: Owns soft-delete / undo / purge semantics for projects.

import '../database/helix_database.dart';

class ProjectsService {
  ProjectsService._(this._db);

  static ProjectsService? _instance;
  static ProjectsService get instance =>
      _instance ??= ProjectsService._(HelixDatabase.instance);

  /// Tests only.
  factory ProjectsService.forTesting(HelixDatabase db) {
    final svc = ProjectsService._(db);
    _instance = svc;
    return svc;
  }

  static void resetForTesting() {
    _instance = null;
  }

  final HelixDatabase _db;

  Stream<List<Project>> watchProjects() =>
      _db.projectDao.watchActiveProjects();

  Stream<List<Project>> watchRecentlyDeleted() =>
      _db.projectDao.watchRecentlyDeleted();

  Future<Project?> getById(String id) => _db.projectDao.getProjectById(id);

  Future<Project> createProject({required String name, String? description}) =>
      _db.projectDao.createProject(name: name, description: description);

  Future<void> updateProject({
    required String id,
    String? name,
    String? description,
    int? chunkSizeTokens,
    int? chunkOverlapTokens,
    int? retrievalTopK,
    double? retrievalMinSimilarity,
  }) =>
      _db.projectDao.updateProject(
        id: id,
        name: name,
        description: description,
        chunkSizeTokens: chunkSizeTokens,
        chunkOverlapTokens: chunkOverlapTokens,
        retrievalTopK: retrievalTopK,
        retrievalMinSimilarity: retrievalMinSimilarity,
      );

  Future<void> softDelete(String id) => _db.projectDao.softDeleteProject(id);

  Future<void> undoDelete(String id) => _db.projectDao.undoDelete(id);

  /// Should be called once on app launch.
  Future<int> purgeExpiredSoftDeletes() =>
      _db.projectDao.purgeExpiredSoftDeletes();
}
```

- [ ] **Step 4: Run tests**

```bash
flutter test test/services/projects/projects_service_test.dart
```

Expected: all PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/services/projects/projects_service.dart test/services/projects/projects_service_test.dart
git commit -m "feat(projects): add ProjectsService singleton"
```

---

### Task 7: DocumentIngestService (without isolate — v1 simplification)

**Design note:** The spec calls for a background isolate. Drift isolates require passing a database handle across isolates which is non-trivial. For the time-crunch v1, we run ingest on the main isolate in a micro-task loop, flushing to the DB between chunks so the UI stays responsive (Drift writes are async and don't block the frame loop much). We can retrofit isolates later if needed; API and persistence layout are unchanged by the move.

**Files:**
- Create: `lib/services/projects/document_ingest_service.dart`
- Create: `lib/services/projects/text_extractor.dart`
- Create: `test/services/projects/document_ingest_service_test.dart`

- [ ] **Step 1: Write the text extractor**

Create `lib/services/projects/text_extractor.dart`:

```dart
// ABOUTME: Extracts text from supported document types (PDF, TXT) for Project RAG.

import 'dart:io';

import 'package:syncfusion_flutter_pdf/pdf.dart';

class ExtractedDocument {
  const ExtractedDocument({
    required this.text,
    required this.pageCount,
    required this.pageBoundaries,
  });

  /// Concatenated full text. Pages separated by `\n\n`.
  final String text;

  /// 1-based page count. 1 for TXT, actual page count for PDFs.
  final int pageCount;

  /// For each page index (0-based), the character offset within `text` where
  /// that page starts. Length == pageCount. Used to map chunk offsets back
  /// to page numbers.
  final List<int> pageBoundaries;
}

class TextExtractor {
  static Future<ExtractedDocument> extract(File file, String contentType) async {
    switch (contentType) {
      case 'txt':
        final text = await file.readAsString();
        return ExtractedDocument(
            text: text, pageCount: 1, pageBoundaries: const [0]);
      case 'pdf':
        return _extractPdf(file);
      default:
        throw ArgumentError('Unsupported content type: $contentType');
    }
  }

  static Future<ExtractedDocument> _extractPdf(File file) async {
    final bytes = await file.readAsBytes();
    final PdfDocument doc = PdfDocument(inputBytes: bytes);
    try {
      final buffer = StringBuffer();
      final boundaries = <int>[];
      final extractor = PdfTextExtractor(doc);
      for (var i = 0; i < doc.pages.count; i++) {
        boundaries.add(buffer.length);
        final pageText = extractor.extractText(startPageIndex: i, endPageIndex: i);
        buffer.write(pageText);
        buffer.write('\n\n');
      }
      return ExtractedDocument(
        text: buffer.toString(),
        pageCount: doc.pages.count,
        pageBoundaries: boundaries,
      );
    } finally {
      doc.dispose();
    }
  }
}
```

- [ ] **Step 2: Write the failing test for the ingest service**

Create `test/services/projects/document_ingest_service_test.dart`:

```dart
import 'dart:io';
import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:flutter_helix/services/database/helix_database.dart';
import 'package:flutter_helix/services/projects/document_ingest_service.dart';
import 'package:flutter_helix/services/projects/openai_embeddings_client.dart';
import 'package:flutter_helix/services/projects/projects_service.dart';

class _FakeEmbeddings implements EmbeddingClient {
  _FakeEmbeddings({this.dim = 4});
  final int dim;
  int callCount = 0;

  @override
  Future<EmbeddingBatchResult> embedBatch(List<String> inputs) async {
    callCount++;
    final vectors = inputs
        .map((t) => Float32List.fromList(
            List.generate(dim, (i) => (t.length + i).toDouble())))
        .toList();
    return EmbeddingBatchResult(vectors: vectors, promptTokens: inputs.length);
  }

  @override
  Future<Float32List> embed(String input) async =>
      (await embedBatch([input])).vectors.single;
}

class _FakeDir extends PathProviderPlatform {
  _FakeDir(this._root);
  final String _root;
  @override
  Future<String?> getApplicationDocumentsPath() async => _root;
}

void main() {
  late HelixDatabase db;
  late Directory tmp;

  setUp(() async {
    db = HelixDatabase.forTesting(NativeDatabase.memory());
    await HelixDatabase.overrideForTesting(db);
    ProjectsService.resetForTesting();
    tmp = await Directory.systemTemp.createTemp('ingest_test');
    PathProviderPlatform.instance = _FakeDir(tmp.path);
  });

  tearDown(() async {
    await HelixDatabase.resetForTesting();
    await db.close();
    await tmp.delete(recursive: true);
  });

  test('ingests a TXT file end-to-end', () async {
    final p = await ProjectsService.forTesting(db).createProject(name: 'p');
    final file = File('${tmp.path}/doc.txt');
    await file.writeAsString(
        'Paragraph one text.\n\nParagraph two text here.');

    final embeddings = _FakeEmbeddings();
    final svc = DocumentIngestService(
      embeddingClientFactory: () => embeddings,
      db: db,
    );

    final events = <IngestEvent>[];
    await for (final e in svc.ingestDocument(
      projectId: p.id,
      filePath: file.path,
      filename: 'doc.txt',
    )) {
      events.add(e);
    }

    expect(events.last, isA<IngestCompleted>());
    final docs = await db.projectDao.listDocumentsForProject(p.id);
    expect(docs, hasLength(1));
    expect(docs.single.ingestStatus, 'ready');
    final chunks = await db.projectDao.loadProjectChunksWithVectors(p.id);
    expect(chunks, isNotEmpty);
    expect(embeddings.callCount, greaterThan(0));
  });

  test('marks document failed and records error on embedding failure',
      () async {
    final p = await ProjectsService.forTesting(db).createProject(name: 'p');
    final file = File('${tmp.path}/doc.txt');
    await file.writeAsString('hello world');

    final svc = DocumentIngestService(
      embeddingClientFactory: () => _FailingEmbeddings(),
      db: db,
    );

    final events = <IngestEvent>[];
    await for (final e in svc.ingestDocument(
      projectId: p.id,
      filePath: file.path,
      filename: 'doc.txt',
    )) {
      events.add(e);
    }

    expect(events.last, isA<IngestFailed>());
    final docs = await db.projectDao.listDocumentsForProject(p.id);
    expect(docs.single.ingestStatus, 'failed');
    expect(docs.single.ingestError, isNotNull);
  });

  test('refuses files above 10 MB cap', () async {
    final p = await ProjectsService.forTesting(db).createProject(name: 'p');
    final file = File('${tmp.path}/big.txt');
    final big = List.filled(11 * 1024 * 1024, 0x41); // 11 MB of 'A'
    await file.writeAsBytes(big);
    final svc = DocumentIngestService(
      embeddingClientFactory: () => _FakeEmbeddings(),
      db: db,
    );
    final events = <IngestEvent>[];
    await for (final e in svc.ingestDocument(
      projectId: p.id,
      filePath: file.path,
      filename: 'big.txt',
    )) {
      events.add(e);
    }
    expect(events.last, isA<IngestFailed>());
    final docs = await db.projectDao.listDocumentsForProject(p.id);
    expect(docs.single.ingestError, contains('10 MB'));
  });

  test('refuses when project is at 50-doc cap', () async {
    final p = await ProjectsService.forTesting(db).createProject(name: 'p');
    for (var i = 0; i < 50; i++) {
      await db.projectDao.insertDocument(
          projectId: p.id,
          filename: 'f$i.txt',
          contentType: 'txt',
          byteSize: 1);
    }
    final file = File('${tmp.path}/over.txt');
    await file.writeAsString('x');
    final svc = DocumentIngestService(
      embeddingClientFactory: () => _FakeEmbeddings(),
      db: db,
    );
    final events = <IngestEvent>[];
    await for (final e in svc.ingestDocument(
      projectId: p.id,
      filePath: file.path,
      filename: 'over.txt',
    )) {
      events.add(e);
    }
    expect(events.last, isA<IngestFailed>());
  });
}

class _FailingEmbeddings implements EmbeddingClient {
  @override
  Future<EmbeddingBatchResult> embedBatch(List<String> inputs) async {
    throw EmbeddingApiException(500, 'boom');
  }

  @override
  Future<Float32List> embed(String input) async =>
      throw EmbeddingApiException(500, 'boom');
}
```

- [ ] **Step 3: Define the EmbeddingClient interface so tests can inject a fake**

Edit `lib/services/projects/openai_embeddings_client.dart` and add at the top of the file (after imports, before `EmbeddingApiException`):

```dart
abstract class EmbeddingClient {
  Future<EmbeddingBatchResult> embedBatch(List<String> inputs);
  Future<Float32List> embed(String input);
}
```

Change the class declaration of `OpenAiEmbeddingsClient` to:

```dart
class OpenAiEmbeddingsClient implements EmbeddingClient {
```

- [ ] **Step 4: Write the ingest service**

Create `lib/services/projects/document_ingest_service.dart`:

```dart
// ABOUTME: Pipeline for ingesting a single document: extract → chunk → embed → persist.
// ABOUTME: Runs on the main isolate but yields between chunks to keep UI responsive.

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../database/helix_database.dart';
import '../database/project_dao.dart';
import 'document_chunker.dart';
import 'embedding_math.dart';
import 'openai_embeddings_client.dart';
import 'text_extractor.dart';

const int _maxBytes = 10 * 1024 * 1024; // 10 MB
const int _maxDocsPerProject = 50;
const int _embedBatchSize = 100;
const String _embeddingModel = 'text-embedding-3-small';

sealed class IngestEvent {
  const IngestEvent();
}

class IngestStarted extends IngestEvent {
  const IngestStarted(this.documentId);
  final String documentId;
}

class IngestExtractingText extends IngestEvent {
  const IngestExtractingText();
}

class IngestChunking extends IngestEvent {
  const IngestChunking();
}

class IngestEmbedding extends IngestEvent {
  const IngestEmbedding(this.chunksDone, this.totalChunks);
  final int chunksDone;
  final int totalChunks;
}

class IngestCompleted extends IngestEvent {
  const IngestCompleted(this.documentId);
  final String documentId;
}

class IngestFailed extends IngestEvent {
  const IngestFailed(this.documentId, this.error);
  final String? documentId;
  final String error;
}

class DocumentIngestService {
  DocumentIngestService({
    required EmbeddingClient Function() embeddingClientFactory,
    HelixDatabase? db,
  })  : _clientFactory = embeddingClientFactory,
        _db = db ?? HelixDatabase.instance;

  final EmbeddingClient Function() _clientFactory;
  final HelixDatabase _db;

  final _globalEvents = StreamController<IngestEvent>.broadcast();
  Stream<IngestEvent> get events => _globalEvents.stream;

  Stream<IngestEvent> ingestDocument({
    required String projectId,
    required String filePath,
    required String filename,
  }) async* {
    String? documentId;
    try {
      // -------- Pre-checks --------
      final srcFile = File(filePath);
      final size = await srcFile.length();
      if (size > _maxBytes) {
        yield* _fail(null, 'File exceeds 10 MB cap (size: $size bytes)');
        return;
      }

      final existing =
          await _db.projectDao.listDocumentsForProject(projectId);
      if (existing.length >= _maxDocsPerProject) {
        yield* _fail(null, 'Project has reached 50-document limit');
        return;
      }

      final contentType = _detectContentType(filename);
      if (contentType == null) {
        yield* _fail(
            null, 'Unsupported file type — only .pdf and .txt are allowed');
        return;
      }

      // -------- Create placeholder doc row --------
      final doc = await _db.projectDao.insertDocument(
        projectId: projectId,
        filename: filename,
        contentType: contentType,
        byteSize: size,
      );
      documentId = doc.id;
      _emit(IngestStarted(doc.id));
      yield IngestStarted(doc.id);

      // Copy file to app docs dir (persistent reference)
      final appDir = await getApplicationDocumentsDirectory();
      final destDir = Directory(p.join(appDir.path, 'projects', projectId));
      await destDir.create(recursive: true);
      final destFile = File(p.join(destDir.path, '${doc.id}_$filename'));
      await srcFile.copy(destFile.path);

      // -------- Extract text --------
      _emit(const IngestExtractingText());
      yield const IngestExtractingText();
      await _db.projectDao.updateDocumentStatus(doc.id, status: 'processing');
      final extracted = await TextExtractor.extract(destFile, contentType);
      if (extracted.text.trim().isEmpty) {
        yield* _fail(
            doc.id,
            'No text could be extracted — scanned PDFs require OCR which is not supported in v1');
        return;
      }

      // -------- Chunk --------
      _emit(const IngestChunking());
      yield const IngestChunking();
      final project = await _db.projectDao.getProjectById(projectId);
      final chunkOpts = ChunkOptions(
        targetTokens: project?.chunkSizeTokens ?? 800,
        overlapTokens: project?.chunkOverlapTokens ?? 100,
      );
      final chunks = DocumentChunker.chunk(extracted.text, chunkOpts);
      if (chunks.isEmpty) {
        yield* _fail(doc.id, 'Chunker produced 0 chunks');
        return;
      }

      // Map chunk -> page range by scanning where chunk text first appears
      // in the original text. Cheap and good enough for v1.
      final withPages = _attachPageRanges(chunks, extracted);

      // -------- Embed in batches --------
      final client = _clientFactory();
      final vectors = <Uint8List>[];
      for (var i = 0; i < withPages.length; i += _embedBatchSize) {
        final end = (i + _embedBatchSize).clamp(0, withPages.length);
        final batch = withPages.sublist(i, end).map((c) => c.text).toList();
        final result = await client.embedBatch(batch);
        for (final v in result.vectors) {
          vectors.add(EmbeddingMath.encodeVector(v));
        }
        _emit(IngestEmbedding(end, withPages.length));
        yield IngestEmbedding(end, withPages.length);
      }

      // -------- Persist --------
      await _db.projectDao.saveChunksAndVectors(
        documentId: doc.id,
        projectId: projectId,
        chunks: withPages
            .map((c) => ChunkToPersist(
                  chunkIndex: c.chunkIndex,
                  text: c.text,
                  tokenCount: c.tokenCount,
                  pageStart: c.pageStart,
                  pageEnd: c.pageEnd,
                ))
            .toList(),
        vectors: vectors,
        embeddingModel: _embeddingModel,
      );
      await _db.projectDao.updateDocumentStatus(
        doc.id,
        status: 'ready',
        pageCount: extracted.pageCount,
      );
      _emit(IngestCompleted(doc.id));
      yield IngestCompleted(doc.id);
    } catch (e) {
      yield* _fail(documentId, e.toString());
    }
  }

  Stream<IngestEvent> _fail(String? docId, String error) async* {
    if (docId != null) {
      try {
        await _db.projectDao
            .updateDocumentStatus(docId, status: 'failed', error: error);
      } catch (_) {/* best-effort */}
    }
    final ev = IngestFailed(docId, error);
    _emit(ev);
    yield ev;
  }

  void _emit(IngestEvent e) {
    if (!_globalEvents.isClosed) _globalEvents.add(e);
  }

  static String? _detectContentType(String filename) {
    final ext = p.extension(filename).toLowerCase();
    if (ext == '.pdf') return 'pdf';
    if (ext == '.txt') return 'txt';
    return null;
  }

  static List<ChunkResult> _attachPageRanges(
      List<ChunkResult> chunks, ExtractedDocument doc) {
    if (doc.pageCount == 1) {
      return chunks
          .map((c) => ChunkResult(
                chunkIndex: c.chunkIndex,
                text: c.text,
                tokenCount: c.tokenCount,
                pageStart: 1,
                pageEnd: 1,
              ))
          .toList();
    }
    final out = <ChunkResult>[];
    int cursor = 0;
    for (final c in chunks) {
      final idx = doc.text.indexOf(c.text, cursor);
      final startChar = idx >= 0 ? idx : cursor;
      final endChar = startChar + c.text.length;
      final pageStart = _pageAtOffset(doc.pageBoundaries, startChar);
      final pageEnd = _pageAtOffset(doc.pageBoundaries, endChar);
      out.add(ChunkResult(
        chunkIndex: c.chunkIndex,
        text: c.text,
        tokenCount: c.tokenCount,
        pageStart: pageStart,
        pageEnd: pageEnd,
      ));
      cursor = endChar;
    }
    return out;
  }

  static int _pageAtOffset(List<int> boundaries, int offset) {
    for (var i = boundaries.length - 1; i >= 0; i--) {
      if (offset >= boundaries[i]) return i + 1; // 1-based page
    }
    return 1;
  }

  void dispose() {
    _globalEvents.close();
  }
}
```

- [ ] **Step 5: Run the tests**

```bash
flutter test test/services/projects/document_ingest_service_test.dart
```

Expected: all PASS. If the `path_provider_platform_interface` import fails, add it to `dev_dependencies` in `pubspec.yaml` (it ships as a transitive dep of `path_provider` so it's likely already available; if not, add it explicitly) and re-run.

- [ ] **Step 6: Run `flutter analyze`**

```bash
flutter analyze
```

Expected: 0 errors.

- [ ] **Step 7: Commit**

```bash
git add lib/services/projects/document_ingest_service.dart lib/services/projects/text_extractor.dart lib/services/projects/openai_embeddings_client.dart test/services/projects/document_ingest_service_test.dart
git commit -m "feat(projects): add DocumentIngestService (extract → chunk → embed → persist)"
```

---

### Task 8: ProjectRagService (retrieval)

**Files:**
- Create: `lib/services/projects/project_rag_service.dart`
- Create: `test/services/projects/project_rag_service_test.dart`

- [ ] **Step 1: Write the failing test**

Create `test/services/projects/project_rag_service_test.dart`:

```dart
import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_helix/services/database/helix_database.dart';
import 'package:flutter_helix/services/database/project_dao.dart';
import 'package:flutter_helix/services/projects/embedding_math.dart';
import 'package:flutter_helix/services/projects/openai_embeddings_client.dart';
import 'package:flutter_helix/services/projects/project_rag_service.dart';

void main() {
  late HelixDatabase db;

  setUp(() async {
    db = HelixDatabase.forTesting(NativeDatabase.memory());
    await HelixDatabase.overrideForTesting(db);
  });

  tearDown(() async {
    await HelixDatabase.resetForTesting();
    await db.close();
  });

  Future<String> seed({
    required List<Float32List> chunkVectors,
    required List<String> chunkTexts,
  }) async {
    final p = await db.projectDao.createProject(name: 'p');
    final d = await db.projectDao.insertDocument(
      projectId: p.id,
      filename: 'f.txt',
      contentType: 'txt',
      byteSize: 1,
    );
    await db.projectDao.saveChunksAndVectors(
      documentId: d.id,
      projectId: p.id,
      chunks: [
        for (var i = 0; i < chunkTexts.length; i++)
          ChunkToPersist(
              chunkIndex: i, text: chunkTexts[i], tokenCount: 1),
      ],
      vectors: chunkVectors.map(EmbeddingMath.encodeVector).toList(),
      embeddingModel: 'text-embedding-3-small',
    );
    await db.projectDao
        .updateDocumentStatus(d.id, status: 'ready', pageCount: 1);
    return p.id;
  }

  test('ranks the most similar chunk first and respects topK', () async {
    final projectId = await seed(
      chunkTexts: ['a', 'b', 'c'],
      chunkVectors: [
        Float32List.fromList([1, 0, 0]),
        Float32List.fromList([0, 1, 0]),
        Float32List.fromList([1, 1, 0]),
      ],
    );

    final svc = ProjectRagService(
      db: db,
      embeddingClient: _StaticEmbeddings(Float32List.fromList([1, 0, 0])),
    );

    final result = await svc.retrieve(
        projectId: projectId, query: 'any', topKOverride: 2);

    expect(result.chunks, hasLength(2));
    expect(result.chunks.first.chunkText, 'a');
    expect(result.chunks.first.similarity, closeTo(1.0, 1e-6));
    expect(result.chunks.last.chunkText, 'c'); // similarity ≈ 0.707
  });

  test('filters below similarity threshold', () async {
    final projectId = await seed(
      chunkTexts: ['a', 'b'],
      chunkVectors: [
        Float32List.fromList([1, 0]),
        Float32List.fromList([0, 1]),
      ],
    );
    final svc = ProjectRagService(
      db: db,
      embeddingClient: _StaticEmbeddings(Float32List.fromList([1, 0])),
    );
    final result = await svc.retrieve(
        projectId: projectId, query: 'x', thresholdOverride: 0.5);
    expect(result.chunks, hasLength(1));
    expect(result.chunks.single.chunkText, 'a');
  });

  test('returns empty chunks when project has no documents', () async {
    final p = await db.projectDao.createProject(name: 'p');
    final svc = ProjectRagService(
      db: db,
      embeddingClient: _StaticEmbeddings(Float32List.fromList([1, 0])),
    );
    final result = await svc.retrieve(projectId: p.id, query: 'x');
    expect(result.chunks, isEmpty);
  });
}

class _StaticEmbeddings implements EmbeddingClient {
  _StaticEmbeddings(this.vector);
  final Float32List vector;
  @override
  Future<EmbeddingBatchResult> embedBatch(List<String> inputs) async =>
      EmbeddingBatchResult(
          vectors: List.filled(inputs.length, vector), promptTokens: 0);

  @override
  Future<Float32List> embed(String input) async => vector;
}
```

- [ ] **Step 2: Run tests to verify failure**

```bash
flutter test test/services/projects/project_rag_service_test.dart
```

Expected: FAIL — file missing.

- [ ] **Step 3: Write the service**

Create `lib/services/projects/project_rag_service.dart`:

```dart
// ABOUTME: Retrieval API for Project RAG. Embeds query, ranks project chunks.
// ABOUTME: Returns top-K with source metadata for prompt injection + citations.

import 'dart:typed_data';

import '../database/helix_database.dart';
import 'embedding_math.dart';
import 'openai_embeddings_client.dart';

class RetrievedChunk {
  const RetrievedChunk({
    required this.chunkId,
    required this.chunkText,
    required this.similarity,
    required this.documentId,
    required this.documentFilename,
    this.pageStart,
    this.pageEnd,
  });
  final String chunkId;
  final String chunkText;
  final double similarity;
  final String documentId;
  final String documentFilename;
  final int? pageStart;
  final int? pageEnd;
}

class RetrievalResult {
  const RetrievalResult({
    required this.chunks,
    required this.totalChunksSearched,
    required this.durationMs,
  });
  final List<RetrievedChunk> chunks;
  final int totalChunksSearched;
  final int durationMs;
}

class ProjectRagService {
  ProjectRagService({
    required HelixDatabase db,
    required EmbeddingClient embeddingClient,
  })  : _db = db,
        _client = embeddingClient;

  static ProjectRagService? _instance;
  static ProjectRagService get instance {
    final inst = _instance;
    if (inst == null) {
      throw StateError('ProjectRagService not initialized. '
          'Call ProjectRagService.initialize() on app startup.');
    }
    return inst;
  }

  static void initialize({
    required HelixDatabase db,
    required EmbeddingClient embeddingClient,
  }) {
    _instance = ProjectRagService(db: db, embeddingClient: embeddingClient);
  }

  static void resetForTesting() {
    _instance = null;
  }

  final HelixDatabase _db;
  final EmbeddingClient _client;

  Future<RetrievalResult> retrieve({
    required String projectId,
    required String query,
    int? topKOverride,
    double? thresholdOverride,
  }) async {
    final started = DateTime.now();
    final project = await _db.projectDao.getProjectById(projectId);
    if (project == null) {
      return RetrievalResult(
          chunks: const [],
          totalChunksSearched: 0,
          durationMs: DateTime.now().difference(started).inMilliseconds);
    }
    final topK = topKOverride ?? project.retrievalTopK;
    final minSim = thresholdOverride ?? project.retrievalMinSimilarity;

    // Load project vectors (all non-deleted).
    final all = await _db.projectDao.loadProjectChunksWithVectors(projectId);
    if (all.isEmpty) {
      return RetrievalResult(
          chunks: const [],
          totalChunksSearched: 0,
          durationMs: DateTime.now().difference(started).inMilliseconds);
    }

    // Load document filenames in one pass for citation display.
    final docIds = all.map((c) => c.chunk.documentId).toSet().toList();
    final docs = await (_db.select(_db.projectDocuments)
          ..where((d) => d.id.isIn(docIds)))
        .get();
    final docById = {for (final d in docs) d.id: d};

    // Embed query.
    final queryVec = await _client.embed(query);

    // Rank.
    final scored = <_Scored>[];
    for (final cv in all) {
      final v = EmbeddingMath.decodeVector(cv.vector);
      if (v.length != queryVec.length) continue; // defensive
      final sim = EmbeddingMath.cosineSimilarity(queryVec, v);
      if (sim >= minSim) {
        scored.add(_Scored(cv.chunk, sim));
      }
    }
    scored.sort((a, b) => b.similarity.compareTo(a.similarity));
    final top = scored.take(topK).toList();

    final chunks = top.map((s) {
      final doc = docById[s.chunk.documentId];
      return RetrievedChunk(
        chunkId: s.chunk.id,
        chunkText: s.chunk.text_,
        similarity: s.similarity,
        documentId: s.chunk.documentId,
        documentFilename: doc?.filename ?? '(unknown)',
        pageStart: s.chunk.pageStart,
        pageEnd: s.chunk.pageEnd,
      );
    }).toList();

    return RetrievalResult(
      chunks: chunks,
      totalChunksSearched: all.length,
      durationMs: DateTime.now().difference(started).inMilliseconds,
    );
  }
}

class _Scored {
  const _Scored(this.chunk, this.similarity);
  final ProjectDocumentChunk chunk;
  final double similarity;
}
```

- [ ] **Step 4: Run tests**

```bash
flutter test test/services/projects/project_rag_service_test.dart
```

Expected: all PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/services/projects/project_rag_service.dart test/services/projects/project_rag_service_test.dart
git commit -m "feat(projects): add ProjectRagService (cosine retrieval + citations)"
```

---

### Task 9: ActiveProjectController

**Files:**
- Create: `lib/services/projects/active_project_controller.dart`
- Create: `test/services/projects/active_project_controller_test.dart`

- [ ] **Step 1: Write the failing test**

Create `test/services/projects/active_project_controller_test.dart`:

```dart
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
```

- [ ] **Step 2: Run tests to verify failure**

```bash
flutter test test/services/projects/active_project_controller_test.dart
```

Expected: FAIL — file missing.

- [ ] **Step 3: Write the controller**

Create `lib/services/projects/active_project_controller.dart`:

```dart
// ABOUTME: Holds the currently-active-for-live project id. Persisted in prefs.

import 'dart:async';

import 'package:shared_preferences/shared_preferences.dart';

const _prefsKey = 'activeProjectId';

class ActiveProjectController {
  ActiveProjectController._(this._prefs, this._activeProjectId);

  static ActiveProjectController? _instance;
  static ActiveProjectController get instance {
    final i = _instance;
    if (i == null) {
      throw StateError('ActiveProjectController.load() must be awaited first');
    }
    return i;
  }

  static Future<ActiveProjectController> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    final c = ActiveProjectController._(prefs, raw);
    _instance = c;
    return c;
  }

  static void resetForTesting() {
    _instance = null;
  }

  final SharedPreferences _prefs;
  String? _activeProjectId;
  final _controller = StreamController<String?>.broadcast();

  String? get activeProjectId => _activeProjectId;
  Stream<String?> get activeProjectStream => _controller.stream;

  Future<void> setActive(String? projectId) async {
    _activeProjectId = projectId;
    if (projectId == null) {
      await _prefs.remove(_prefsKey);
    } else {
      await _prefs.setString(_prefsKey, projectId);
    }
    _controller.add(projectId);
  }
}
```

- [ ] **Step 4: Run tests**

```bash
flutter test test/services/projects/active_project_controller_test.dart
```

Expected: all PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/services/projects/active_project_controller.dart test/services/projects/active_project_controller_test.dart
git commit -m "feat(projects): add ActiveProjectController (persisted active project)"
```

---

## ConversationEngine integration

### Task 10: ProjectContextFormatter — prepend block builder

**Files:**
- Create: `lib/services/projects/project_context_formatter.dart`
- Create: `test/services/projects/project_context_formatter_test.dart`

Pure function — easy to unit test without mocking the engine.

- [ ] **Step 1: Write the failing test**

Create `test/services/projects/project_context_formatter_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_helix/services/projects/project_context_formatter.dart';
import 'package:flutter_helix/services/projects/project_rag_service.dart';

void main() {
  test('prepends PROJECT CONTEXT block with numbered excerpts', () {
    const base = 'You are Helix, a helpful assistant.';
    final result = ProjectContextFormatter.prepend(base, [
      const RetrievedChunk(
        chunkId: 'c1',
        chunkText: 'Revenue was \$4.2M.',
        similarity: 0.9,
        documentId: 'd1',
        documentFilename: 'Q3.pdf',
        pageStart: 7,
        pageEnd: 7,
      ),
      const RetrievedChunk(
        chunkId: 'c2',
        chunkText: 'Margin improved.',
        similarity: 0.8,
        documentId: 'd2',
        documentFilename: 'exec-summary.txt',
      ),
    ]);
    expect(result, startsWith('PROJECT CONTEXT'));
    expect(result, contains('[1]'));
    expect(result, contains('Revenue was \$4.2M'));
    expect(result, contains('Q3.pdf p.7'));
    expect(result, contains('[2]'));
    expect(result, contains('exec-summary.txt'));
    expect(result, contains(base));
    // Instruction appears before the excerpts
    expect(result.indexOf('Prefer facts'), lessThan(result.indexOf('[1]')));
    // Base prompt appears after the excerpts block
    expect(result.indexOf(base), greaterThan(result.indexOf('[2]')));
  });

  test('returns base unchanged when chunks empty', () {
    const base = 'base';
    expect(ProjectContextFormatter.prepend(base, const []), base);
  });
}
```

- [ ] **Step 2: Run tests to verify failure**

```bash
flutter test test/services/projects/project_context_formatter_test.dart
```

Expected: FAIL — file missing.

- [ ] **Step 3: Write the formatter**

Create `lib/services/projects/project_context_formatter.dart`:

```dart
// ABOUTME: Formats retrieved chunks as a PROJECT CONTEXT preamble for the system prompt.

import 'project_rag_service.dart';

class ProjectContextFormatter {
  /// Prepends a numbered PROJECT CONTEXT block to [baseSystemPrompt].
  /// Returns [baseSystemPrompt] unchanged when [chunks] is empty.
  static String prepend(String baseSystemPrompt, List<RetrievedChunk> chunks) {
    if (chunks.isEmpty) return baseSystemPrompt;
    final b = StringBuffer();
    b.writeln('PROJECT CONTEXT');
    b.writeln(
        'The following excerpts are from the user\'s project documents. '
        'Prefer facts from these excerpts over your general knowledge. '
        'Cite with [N] markers matching the numbered excerpts below. '
        'If the excerpts do not contain the answer, answer from general '
        'knowledge without citations.');
    b.writeln();
    for (var i = 0; i < chunks.length; i++) {
      final c = chunks[i];
      final source = _sourceLabel(c);
      b.writeln('[${i + 1}] $source');
      b.writeln(c.chunkText);
      b.writeln();
    }
    b.writeln('---');
    b.writeln();
    b.write(baseSystemPrompt);
    return b.toString();
  }

  static String _sourceLabel(RetrievedChunk c) {
    if (c.pageStart != null && c.pageEnd != null) {
      if (c.pageStart == c.pageEnd) {
        return '${c.documentFilename} p.${c.pageStart}';
      }
      return '${c.documentFilename} p.${c.pageStart}-${c.pageEnd}';
    }
    return c.documentFilename;
  }
}
```

- [ ] **Step 4: Run tests**

```bash
flutter test test/services/projects/project_context_formatter_test.dart
```

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/services/projects/project_context_formatter.dart test/services/projects/project_context_formatter_test.dart
git commit -m "feat(projects): add ProjectContextFormatter (system prompt preamble)"
```

---

### Task 11: Wire retrieval into ConversationEngine._generateResponse

**Files:**
- Modify: `lib/services/conversation_engine.dart`
- Create: `test/services/conversation_engine_project_rag_test.dart`

- [ ] **Step 1: Read the target region**

Read `lib/services/conversation_engine.dart` lines 2445-2490 (around the existing `systemPrompt` assembly in `_generateResponse`). Confirm the base-prompt line is at/near `final baseSystemPrompt = overrideSystemPrompt ?? _getSystemPrompt();`. Run:

```bash
grep -n "final baseSystemPrompt = overrideSystemPrompt" lib/services/conversation_engine.dart
```

Note the exact line number. If it has moved, adjust Step 3 accordingly.

- [ ] **Step 2: Write the failing test**

Create `test/services/conversation_engine_project_rag_test.dart`:

```dart
import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_helix/services/conversation_engine.dart';
import 'package:flutter_helix/services/database/helix_database.dart';
import 'package:flutter_helix/services/database/project_dao.dart';
import 'package:flutter_helix/services/llm/llm_provider.dart';
import 'package:flutter_helix/services/llm/llm_service.dart';
import 'package:flutter_helix/services/projects/active_project_controller.dart';
import 'package:flutter_helix/services/projects/embedding_math.dart';
import 'package:flutter_helix/services/projects/openai_embeddings_client.dart';
import 'package:flutter_helix/services/projects/project_rag_service.dart';
import 'package:flutter_helix/services/settings_manager.dart';

import 'helpers/test_helpers.dart';

class _StaticEmbeddings implements EmbeddingClient {
  _StaticEmbeddings(this.vec);
  final Float32List vec;
  @override
  Future<EmbeddingBatchResult> embedBatch(List<String> inputs) async =>
      EmbeddingBatchResult(
          vectors: List.filled(inputs.length, vec), promptTokens: 0);
  @override
  Future<Float32List> embed(String input) async => vec;
}

void main() {
  // This test exercises the single new code path in _generateResponse:
  // when ActiveProjectController has an id set, ProjectRagService.retrieve
  // is called and its chunks are formatted into the system prompt.
  // It uses the existing FakeJsonProvider helper to capture the prompt.

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await ActiveProjectController.load();
    ActiveProjectController.resetForTesting();
    await ActiveProjectController.load();
  });

  tearDown(() async {
    ProjectRagService.resetForTesting();
    ActiveProjectController.resetForTesting();
  });

  test(
      'prepends PROJECT CONTEXT when active project set and retrieval returns chunks',
      () async {
    final db = HelixDatabase.forTesting(NativeDatabase.memory());
    await HelixDatabase.overrideForTesting(db);
    await SettingsManager.instance.initialize();

    // Seed a project with one chunk whose embedding matches the fake query vec.
    final p = await db.projectDao.createProject(name: 'Deck');
    final d = await db.projectDao.insertDocument(
        projectId: p.id,
        filename: 'deck.pdf',
        contentType: 'pdf',
        byteSize: 1);
    await db.projectDao.saveChunksAndVectors(
      documentId: d.id,
      projectId: p.id,
      chunks: const [
        ChunkToPersist(
            chunkIndex: 0,
            text: 'Revenue was \$4.2M in Q3.',
            tokenCount: 6,
            pageStart: 7,
            pageEnd: 7),
      ],
      vectors: [EmbeddingMath.encodeVector(Float32List.fromList([1, 0, 0]))],
      embeddingModel: 'text-embedding-3-small',
    );
    await db.projectDao.updateDocumentStatus(d.id, status: 'ready', pageCount: 10);
    await ActiveProjectController.instance.setActive(p.id);

    ProjectRagService.initialize(
      db: db,
      embeddingClient:
          _StaticEmbeddings(Float32List.fromList([1, 0, 0])),
    );

    final fake = FakeJsonProvider(streamResponses: [
      const FakeStreamResponse(['Q3 revenue was \$4.2M. [1]']),
    ]);
    LlmService.instance.setActiveProviderForTesting(fake);

    final engine = ConversationEngine.instance;
    // Simulate a direct generate call via the internal helper method. If your
    // engine exposes a test seam, use it; otherwise invoke the public
    // ingestion path that leads to _generateResponse for a question.
    // For this test we assume there's an `askDirect(question)` helper; if
    // not, port the public method equivalent used by tests in
    // conversation_engine_test.dart and adapt.
    await engine.askDirectForTesting('How much revenue in Q3?');

    // Assert that the fake provider received a system prompt containing our chunk
    expect(fake.capturedSystemPrompts.last, contains('PROJECT CONTEXT'));
    expect(fake.capturedSystemPrompts.last, contains('[1]'));
    expect(fake.capturedSystemPrompts.last, contains('Revenue was \$4.2M in Q3.'));
    expect(fake.capturedSystemPrompts.last, contains('deck.pdf p.7'));

    await engine.dispose();
    await HelixDatabase.resetForTesting();
    await db.close();
  });

  test('does not modify prompt when no active project set', () async {
    final db = HelixDatabase.forTesting(NativeDatabase.memory());
    await HelixDatabase.overrideForTesting(db);
    await SettingsManager.instance.initialize();

    // Active project controller default = null
    ProjectRagService.initialize(
      db: db,
      embeddingClient:
          _StaticEmbeddings(Float32List.fromList([1, 0, 0])),
    );

    final fake = FakeJsonProvider(streamResponses: [
      const FakeStreamResponse(['plain answer']),
    ]);
    LlmService.instance.setActiveProviderForTesting(fake);

    final engine = ConversationEngine.instance;
    await engine.askDirectForTesting('hello?');

    expect(fake.capturedSystemPrompts.last, isNot(contains('PROJECT CONTEXT')));

    await engine.dispose();
    await HelixDatabase.resetForTesting();
    await db.close();
  });
}
```

Note: the test calls `engine.askDirectForTesting(...)`. If that helper doesn't yet exist in `ConversationEngine`, add it as a thin public wrapper over the private `_generateResponse` method in Step 3, guarded by a comment saying "test-only seam."

- [ ] **Step 3: Modify `ConversationEngine._generateResponse`**

Open `lib/services/conversation_engine.dart`. At the top of the file, add imports:

```dart
import 'projects/active_project_controller.dart';
import 'projects/project_context_formatter.dart';
import 'projects/project_rag_service.dart';
```

Locate `final baseSystemPrompt = overrideSystemPrompt ?? _getSystemPrompt();` inside `_generateResponse`. Immediately after it, before `final systemPrompt = PromptAssembler.assembleSystemPrompt(baseSystemPrompt);`, insert the retrieval block:

```dart
      // Project RAG enrichment: if an active project is selected, retrieve
      // relevant chunks and prepend them as PROJECT CONTEXT. On any failure
      // (API down, missing key), fall through silently — user still gets a
      // general-knowledge answer.
      var effectiveBasePrompt = baseSystemPrompt;
      List<RetrievedChunk> activeCitations = const [];
      final activeProjectId =
          ActiveProjectController.instance.activeProjectId;
      if (activeProjectId != null) {
        try {
          final rag = await ProjectRagService.instance
              .retrieve(projectId: activeProjectId, query: question);
          if (rag.chunks.isNotEmpty) {
            effectiveBasePrompt =
                ProjectContextFormatter.prepend(baseSystemPrompt, rag.chunks);
            activeCitations = rag.chunks;
          }
        } catch (e) {
          // Log and continue. The engine should never fail a response because
          // project retrieval failed.
          // ignore: avoid_print
          print('[ConversationEngine] project retrieval failed: $e');
        }
      }
```

Then change the following line from:

```dart
      final systemPrompt = PromptAssembler.assembleSystemPrompt(
        baseSystemPrompt,
      );
```

to:

```dart
      final systemPrompt = PromptAssembler.assembleSystemPrompt(
        effectiveBasePrompt,
      );
```

Also, right below the existing private field declarations near the top of the class, add:

```dart
  final _projectCitationsController =
      StreamController<List<RetrievedChunk>>.broadcast();

  /// Emits the citation sources used for the most recent project-enriched response.
  Stream<List<RetrievedChunk>> get projectCitationsStream =>
      _projectCitationsController.stream;
```

And publish citations after successful retrieval. Right after `activeCitations = rag.chunks;`, add:

```dart
            _projectCitationsController.add(activeCitations);
```

(The import for `RetrievedChunk` comes from `project_rag_service.dart` which we imported above.)

Add a test-only seam near the bottom of `ConversationEngine` (before the final `}`):

```dart
  /// Test-only: directly runs a response generation for [question].
  /// Bypasses transcription / question detection.
  Future<void> askDirectForTesting(String question) async {
    await _generateResponse(question, responseToken: _nextResponseToken());
  }
```

If `_nextResponseToken()` or equivalent exists, use it. Otherwise locate the token-issuing helper near other `_generateResponse` callers (line ~1041 or ~1437) and mirror the pattern.

Also ensure `dispose()` on the engine (if present) closes `_projectCitationsController`. Locate the existing dispose and append:

```dart
    await _projectCitationsController.close();
```

- [ ] **Step 4: Regenerate code and run tests**

```bash
flutter analyze
flutter test test/services/conversation_engine_project_rag_test.dart
```

Expected: analyze clean, tests PASS.

If `askDirectForTesting` can't be wired cleanly, fall back to driving the public method the existing `conversation_engine_test.dart` uses (e.g., `processTranscription` with an `isFinal: true` question text). Mirror that pattern instead.

- [ ] **Step 5: Run the full conversation engine test suite to check for regressions**

```bash
flutter test test/services/conversation_engine_test.dart test/services/conversation_engine_error_test.dart test/services/conversation_engine_modes_test.dart
```

Expected: all PASS. No regression from the insertion.

- [ ] **Step 6: Commit**

```bash
git add lib/services/conversation_engine.dart test/services/conversation_engine_project_rag_test.dart
git commit -m "feat(projects): hook ConversationEngine to inject project context + emit citations"
```

---

## UI layer

### Task 12: Wire services and purge on app launch

**Files:**
- Modify: `lib/main.dart` (or wherever app init happens)

- [ ] **Step 1: Locate init order**

Run:

```bash
grep -n "SettingsManager\.instance\.initialize\|LlmService" lib/main.dart | head -10
```

- [ ] **Step 2: Add initialization steps**

In `lib/main.dart`, locate the main function (or `_bootstrap`). After `SettingsManager.instance.initialize()` and before `runApp(...)`, add:

```dart
  // Project RAG init
  await ActiveProjectController.load();
  final openAiKey =
      await SettingsManager.instance.getApiKey('openai') ?? '';
  ProjectRagService.initialize(
    db: HelixDatabase.instance,
    embeddingClient: OpenAiEmbeddingsClient(
      apiKey: openAiKey,
      model: 'text-embedding-3-small',
    ),
  );
  // Best-effort purge of expired soft-deletes
  unawaited(ProjectsService.instance.purgeExpiredSoftDeletes());
```

Add imports at the top of the file:

```dart
import 'services/projects/active_project_controller.dart';
import 'services/projects/openai_embeddings_client.dart';
import 'services/projects/project_rag_service.dart';
import 'services/projects/projects_service.dart';
```

- [ ] **Step 3: Handle API key change**

Find where `SettingsManager` broadcasts key changes. Likely there's an `onSettingsChanged` stream. Subscribe to it and re-initialize the embeddings client when the OpenAI key changes. Add after the init block:

```dart
  SettingsManager.instance.onSettingsChanged.listen((_) async {
    final key = await SettingsManager.instance.getApiKey('openai') ?? '';
    ProjectRagService.initialize(
      db: HelixDatabase.instance,
      embeddingClient: OpenAiEmbeddingsClient(
          apiKey: key, model: 'text-embedding-3-small'),
    );
  });
```

If `onSettingsChanged` doesn't exist or emits for specific keys only, adapt — simplest fallback: rebuild the client lazily inside `ProjectRagService.retrieve` and `DocumentIngestService` by reading the key each time. If so, change `ProjectRagService.initialize` to accept a `Future<EmbeddingClient> Function()` factory and remove the listen block.

- [ ] **Step 4: Run analyze**

```bash
flutter analyze
```

Expected: 0 errors.

- [ ] **Step 5: Commit**

```bash
git add lib/main.dart
git commit -m "feat(projects): wire ProjectRag services + purge on app launch"
```

---

### Task 13: Add Projects tab to LiveHistoryScreen

**Files:**
- Modify: `lib/screens/live_history_screen.dart`
- Create: `lib/screens/projects/projects_list_screen.dart`

- [ ] **Step 1: Create a skeleton Projects list screen**

Create `lib/screens/projects/projects_list_screen.dart`:

```dart
// ABOUTME: Projects tab — list active projects and recently-deleted.

import 'package:flutter/material.dart';

import '../../services/database/helix_database.dart';
import '../../services/projects/projects_service.dart';
import '../../theme/helix_theme.dart';
import '../../utils/i18n.dart';
import 'project_detail_screen.dart';

class ProjectsListScreen extends StatefulWidget {
  const ProjectsListScreen({super.key});

  @override
  State<ProjectsListScreen> createState() => _ProjectsListScreenState();
}

class _ProjectsListScreenState extends State<ProjectsListScreen> {
  bool _showDeleted = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: SegmentedButton<bool>(
                  segments: [
                    ButtonSegment(
                        value: false, label: Text(tr('Active', '当前'))),
                    ButtonSegment(
                        value: true,
                        label: Text(tr('Recently deleted', '回收站'))),
                  ],
                  selected: {_showDeleted},
                  onSelectionChanged: (s) =>
                      setState(() => _showDeleted = s.first),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                tooltip: tr('New project', '新建项目'),
                icon: const Icon(Icons.add),
                onPressed: () => _showNewProjectDialog(context),
              ),
            ],
          ),
        ),
        Expanded(
          child: StreamBuilder<List<Project>>(
            stream: _showDeleted
                ? ProjectsService.instance.watchRecentlyDeleted()
                : ProjectsService.instance.watchProjects(),
            builder: (ctx, snap) {
              if (!snap.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final items = snap.data!;
              if (items.isEmpty) {
                return Center(
                  child: Text(
                    _showDeleted
                        ? tr('No deleted projects.', '没有已删除的项目。')
                        : tr('No projects yet. Tap + to create one.',
                            '还没有项目，点击 + 创建一个。'),
                    style: const TextStyle(color: HelixTheme.textMuted),
                  ),
                );
              }
              return ListView.separated(
                padding: const EdgeInsets.all(12),
                itemCount: items.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (_, i) {
                  final p = items[i];
                  return _ProjectCard(
                    project: p,
                    deleted: _showDeleted,
                    onTap: _showDeleted
                        ? null
                        : () => Navigator.of(context).push(MaterialPageRoute(
                              builder: (_) =>
                                  ProjectDetailScreen(projectId: p.id),
                            )),
                    onUndo: _showDeleted
                        ? () async => ProjectsService.instance.undoDelete(p.id)
                        : null,
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Future<void> _showNewProjectDialog(BuildContext context) async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(tr('New project', '新建项目')),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(hintText: tr('Project name', '项目名称')),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(tr('Cancel', '取消'))),
          TextButton(
              onPressed: () =>
                  Navigator.pop(ctx, controller.text.trim()),
              child: Text(tr('Create', '创建'))),
        ],
      ),
    );
    if (name != null && name.isNotEmpty) {
      await ProjectsService.instance.createProject(name: name);
    }
  }
}

class _ProjectCard extends StatelessWidget {
  const _ProjectCard({
    required this.project,
    required this.deleted,
    this.onTap,
    this.onUndo,
  });
  final Project project;
  final bool deleted;
  final VoidCallback? onTap;
  final VoidCallback? onUndo;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: deleted ? HelixTheme.surface.withOpacity(0.5) : HelixTheme.surface,
      child: ListTile(
        title: Text(project.name,
            style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(project.description ?? '',
            maxLines: 1, overflow: TextOverflow.ellipsis),
        onTap: onTap,
        trailing: deleted
            ? TextButton(onPressed: onUndo, child: Text(tr('Undo', '撤销')))
            : const Icon(Icons.chevron_right, color: HelixTheme.textMuted),
      ),
    );
  }
}
```

- [ ] **Step 2: Create a placeholder project detail screen**

Create `lib/screens/projects/project_detail_screen.dart`:

```dart
// ABOUTME: Project detail — documents list, upload, active-for-live toggle,
// ABOUTME: settings sheet, and "Ask this project" query box.

import 'package:flutter/material.dart';

class ProjectDetailScreen extends StatelessWidget {
  const ProjectDetailScreen({super.key, required this.projectId});
  final String projectId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Project')),
      body: const Center(child: Text('Project detail — coming in next task')),
    );
  }
}
```

(We'll fill this in in Task 14.)

- [ ] **Step 3: Add the third tab to `LiveHistoryScreen`**

Open `lib/screens/live_history_screen.dart`. Add import:

```dart
import 'projects/projects_list_screen.dart';
```

Change `DefaultTabController(length: 2,` to `length: 3,`. Add a third `Tab` to the `tabs:` list:

```dart
                        tabs: [
                          Tab(text: tr('Live', '实时')),
                          Tab(text: tr('History', '历史')),
                          Tab(text: tr('Projects', '项目')),
                        ],
```

Add the third child to the `TabBarView`:

```dart
        body: const TabBarView(
          children: [
            DetailAnalysisScreen(),
            ConversationHistoryScreen(),
            ProjectsListScreen(),
          ],
        ),
```

- [ ] **Step 4: Run analyze**

```bash
flutter analyze
```

Expected: 0 errors.

- [ ] **Step 5: Widget test**

Create `test/screens/projects_list_screen_test.dart`:

```dart
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_helix/screens/projects/projects_list_screen.dart';
import 'package:flutter_helix/services/database/helix_database.dart';
import 'package:flutter_helix/services/projects/projects_service.dart';

void main() {
  setUp(() async {
    final db = HelixDatabase.forTesting(NativeDatabase.memory());
    await HelixDatabase.overrideForTesting(db);
    ProjectsService.resetForTesting();
    ProjectsService.forTesting(db);
  });

  testWidgets('renders empty state when no projects', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: ProjectsListScreen())));
    await tester.pumpAndSettle();
    expect(find.textContaining('No projects yet'), findsOneWidget);
  });

  testWidgets('creating a project via dialog adds it to the list',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: ProjectsListScreen())));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Q3');
    await tester.tap(find.text('Create'));
    await tester.pumpAndSettle();
    expect(find.text('Q3'), findsOneWidget);
  });
}
```

Run:

```bash
flutter test test/screens/projects_list_screen_test.dart
```

Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add lib/screens/projects/ lib/screens/live_history_screen.dart test/screens/projects_list_screen_test.dart
git commit -m "feat(projects): add Projects tab to LiveHistoryScreen with empty/list/new flow"
```

---

### Task 14: Flesh out ProjectDetailScreen — docs, upload, settings, active toggle, Ask

**Files:**
- Modify: `lib/screens/projects/project_detail_screen.dart`
- Create: `lib/screens/projects/project_ask_dialog.dart`
- Create: `lib/screens/projects/project_settings_sheet.dart`

This task is the biggest UI piece. Break it into well-scoped sub-steps.

- [ ] **Step 1: Project settings bottom sheet**

Create `lib/screens/projects/project_settings_sheet.dart`:

```dart
// ABOUTME: Bottom sheet for per-project RAG tuning (chunk size, topK, threshold).

import 'package:flutter/material.dart';

import '../../services/database/helix_database.dart';
import '../../services/projects/projects_service.dart';

class ProjectSettingsSheet extends StatefulWidget {
  const ProjectSettingsSheet({super.key, required this.project});
  final Project project;

  @override
  State<ProjectSettingsSheet> createState() => _ProjectSettingsSheetState();
}

class _ProjectSettingsSheetState extends State<ProjectSettingsSheet> {
  late int _chunk;
  late int _overlap;
  late int _topK;
  late double _threshold;

  @override
  void initState() {
    super.initState();
    _chunk = widget.project.chunkSizeTokens;
    _overlap = widget.project.chunkOverlapTokens;
    _topK = widget.project.retrievalTopK;
    _threshold = widget.project.retrievalMinSimilarity;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Project settings',
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          _Slider(
            label: 'Chunk size (tokens)',
            value: _chunk.toDouble(),
            min: 200,
            max: 2000,
            divisions: 36,
            onChanged: (v) => setState(() => _chunk = v.round()),
          ),
          _Slider(
            label: 'Chunk overlap (tokens)',
            value: _overlap.toDouble(),
            min: 0,
            max: 400,
            divisions: 40,
            onChanged: (v) => setState(() => _overlap = v.round()),
          ),
          _Slider(
            label: 'Top-K results',
            value: _topK.toDouble(),
            min: 1,
            max: 15,
            divisions: 14,
            onChanged: (v) => setState(() => _topK = v.round()),
          ),
          _Slider(
            label:
                'Similarity threshold (${_threshold.toStringAsFixed(2)})',
            value: _threshold,
            min: 0.0,
            max: 1.0,
            divisions: 20,
            onChanged: (v) => setState(() => _threshold = v),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              TextButton(
                onPressed: () => setState(() {
                  _chunk = 800;
                  _overlap = 100;
                  _topK = 5;
                  _threshold = 0.3;
                }),
                child: const Text('Reset to defaults'),
              ),
              const Spacer(),
              FilledButton(
                onPressed: () async {
                  await ProjectsService.instance.updateProject(
                    id: widget.project.id,
                    chunkSizeTokens: _chunk,
                    chunkOverlapTokens: _overlap,
                    retrievalTopK: _topK,
                    retrievalMinSimilarity: _threshold,
                  );
                  if (!mounted) return;
                  Navigator.of(context).pop();
                },
                child: const Text('Save'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Slider extends StatelessWidget {
  const _Slider({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.onChanged,
  });
  final String label;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('$label: ${value.round()}'),
        Slider(
            value: value,
            min: min,
            max: max,
            divisions: divisions,
            onChanged: onChanged),
      ],
    );
  }
}
```

- [ ] **Step 2: "Ask this project" dialog**

Create `lib/screens/projects/project_ask_dialog.dart`:

```dart
// ABOUTME: Inline query dialog that streams an answer grounded in project docs.

import 'package:flutter/material.dart';

import '../../services/llm/llm_provider.dart';
import '../../services/llm/llm_service.dart';
import '../../services/projects/project_context_formatter.dart';
import '../../services/projects/project_rag_service.dart';
import '../../services/settings_manager.dart';

class ProjectAskDialog extends StatefulWidget {
  const ProjectAskDialog({super.key, required this.projectId});
  final String projectId;
  @override
  State<ProjectAskDialog> createState() => _ProjectAskDialogState();
}

class _ProjectAskDialogState extends State<ProjectAskDialog> {
  final _ctrl = TextEditingController();
  String _answer = '';
  bool _busy = false;
  List<RetrievedChunk> _citations = const [];

  Future<void> _ask() async {
    final q = _ctrl.text.trim();
    if (q.isEmpty) return;
    setState(() {
      _busy = true;
      _answer = '';
      _citations = const [];
    });
    try {
      final rag = await ProjectRagService.instance
          .retrieve(projectId: widget.projectId, query: q);
      final basePrompt = 'You are Helix, answering questions about the '
          'user\'s project documents. Be concise.';
      final systemPrompt =
          ProjectContextFormatter.prepend(basePrompt, rag.chunks);
      _citations = rag.chunks;

      await for (final chunk in LlmService.instance.streamResponse(
        systemPrompt: systemPrompt,
        messages: [ChatMessage(role: 'user', content: q)],
        temperature: SettingsManager.instance.temperature,
        model: SettingsManager.instance.resolvedSmartModel,
      )) {
        setState(() => _answer += chunk);
      }
    } catch (e) {
      setState(() => _answer = 'Error: $e');
    } finally {
      setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Ask this project'),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _ctrl,
              decoration: const InputDecoration(hintText: 'Your question'),
              autofocus: true,
              onSubmitted: (_) => _ask(),
            ),
            const SizedBox(height: 12),
            if (_busy) const LinearProgressIndicator(),
            if (_answer.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: SelectableText(_answer),
              ),
            if (_citations.isNotEmpty) ...[
              const Divider(),
              const Text('Sources',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              for (var i = 0; i < _citations.length; i++)
                Text('[${i + 1}] ${_citations[i].documentFilename}'
                    '${_citations[i].pageStart != null ? ' p.${_citations[i].pageStart}' : ''}'),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close')),
        FilledButton(onPressed: _busy ? null : _ask, child: const Text('Ask')),
      ],
    );
  }
}
```

- [ ] **Step 3: Full `ProjectDetailScreen`**

Replace `lib/screens/projects/project_detail_screen.dart`:

```dart
// ABOUTME: Project detail — documents list, upload, active-for-live toggle,
// ABOUTME: settings sheet, and "Ask this project" query box.

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../services/database/helix_database.dart';
import '../../services/projects/active_project_controller.dart';
import '../../services/projects/document_ingest_service.dart';
import '../../services/projects/openai_embeddings_client.dart';
import '../../services/projects/projects_service.dart';
import '../../services/settings_manager.dart';
import 'project_ask_dialog.dart';
import 'project_settings_sheet.dart';

class ProjectDetailScreen extends StatefulWidget {
  const ProjectDetailScreen({super.key, required this.projectId});
  final String projectId;

  @override
  State<ProjectDetailScreen> createState() => _ProjectDetailScreenState();
}

class _ProjectDetailScreenState extends State<ProjectDetailScreen> {
  late DocumentIngestService _ingest;

  @override
  void initState() {
    super.initState();
    _ingest = DocumentIngestService(
      embeddingClientFactory: () => OpenAiEmbeddingsClient(
        apiKey: SettingsManager.instance
                    .cachedOpenAiApiKey ?? // or adjust if your settings stores differently
                '',
        model: 'text-embedding-3-small',
      ),
    );
  }

  @override
  void dispose() {
    _ingest.dispose();
    super.dispose();
  }

  Future<void> _upload(String projectId) async {
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'txt'],
      withData: false,
    );
    if (picked == null || picked.files.isEmpty) return;
    final f = picked.files.single;
    final path = f.path;
    if (path == null) return;

    final sub = _ingest
        .ingestDocument(
            projectId: projectId, filePath: path, filename: f.name)
        .listen((event) {
      if (event is IngestFailed) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Ingest failed: ${event.error}')));
      }
      if (event is IngestCompleted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Document ready.')));
      }
    });
    await sub.asFuture<void>().catchError((_) {});
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Project>>(
      stream: ProjectsService.instance.watchProjects(),
      builder: (ctx, snap) {
        final project = snap.data?.firstWhere(
          (p) => p.id == widget.projectId,
          orElse: () => Project(
            id: widget.projectId,
            name: '',
            description: null,
            createdAt: 0,
            updatedAt: 0,
            deletedAt: null,
            chunkSizeTokens: 800,
            chunkOverlapTokens: 100,
            retrievalTopK: 5,
            retrievalMinSimilarity: 0.3,
          ),
        );
        if (project == null || project.name.isEmpty) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        return Scaffold(
          appBar: AppBar(
            title: Text(project.name),
            actions: [
              IconButton(
                  tooltip: 'Ask this project',
                  icon: const Icon(Icons.chat_bubble_outline),
                  onPressed: () => showDialog(
                        context: context,
                        builder: (_) =>
                            ProjectAskDialog(projectId: project.id),
                      )),
              IconButton(
                  tooltip: 'Settings',
                  icon: const Icon(Icons.tune),
                  onPressed: () => showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        builder: (_) =>
                            ProjectSettingsSheet(project: project),
                      )),
              IconButton(
                tooltip: 'Delete',
                icon: const Icon(Icons.delete_outline),
                onPressed: () async {
                  await ProjectsService.instance.softDelete(project.id);
                  if (!mounted) return;
                  Navigator.of(context).pop();
                },
              ),
            ],
          ),
          body: Column(
            children: [
              _ActiveForLiveTile(project: project),
              Expanded(child: _DocumentsList(projectId: project.id)),
            ],
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => _upload(project.id),
            icon: const Icon(Icons.upload_file),
            label: const Text('Upload'),
          ),
        );
      },
    );
  }
}

class _ActiveForLiveTile extends StatelessWidget {
  const _ActiveForLiveTile({required this.project});
  final Project project;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<String?>(
      stream: ActiveProjectController.instance.activeProjectStream,
      initialData: ActiveProjectController.instance.activeProjectId,
      builder: (_, snap) {
        final isActive = snap.data == project.id;
        return ListTile(
          leading: Icon(isActive ? Icons.star : Icons.star_border,
              color: isActive ? Colors.amber : null),
          title: Text(isActive
              ? 'Active for live session'
              : 'Use for live session'),
          trailing: Switch(
            value: isActive,
            onChanged: (v) => ActiveProjectController.instance
                .setActive(v ? project.id : null),
          ),
        );
      },
    );
  }
}

class _DocumentsList extends StatelessWidget {
  const _DocumentsList({required this.projectId});
  final String projectId;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<ProjectDocument>>(
      stream: HelixDatabase.instance.projectDao
          .watchDocumentsForProject(projectId),
      builder: (_, snap) {
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs = snap.data!;
        if (docs.isEmpty) {
          return const Center(
              child: Text('No documents. Tap Upload to add one.'));
        }
        return ListView.separated(
          padding: const EdgeInsets.all(12),
          itemCount: docs.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (_, i) {
            final d = docs[i];
            return ListTile(
              leading: Icon(d.contentType == 'pdf'
                  ? Icons.picture_as_pdf
                  : Icons.description),
              title: Text(d.filename),
              subtitle: Text(
                  'Status: ${d.ingestStatus}${d.pageCount != null ? '  ·  ${d.pageCount} pages' : ''}'),
              trailing: IconButton(
                icon: const Icon(Icons.delete_outline),
                onPressed: () =>
                    HelixDatabase.instance.projectDao.softDeleteDocument(d.id),
              ),
            );
          },
        );
      },
    );
  }
}
```

Note: if `SettingsManager.instance.cachedOpenAiApiKey` doesn't exist, either add a sync cached getter to `SettingsManager` (reading the same SecureStorage value asynchronously and caching it) or use `ProjectRagService`'s client indirectly by passing a closure. Check existing usage:

```bash
grep -n "getApiKey\|cachedOpenAi" lib/services/settings_manager.dart
```

If only async `getApiKey` exists, modify `DocumentIngestService.ingestDocument` to await the key before constructing a client. Adjust the factory signature: `Future<EmbeddingClient> Function()`.

- [ ] **Step 4: Run analyze**

```bash
flutter analyze
```

Expected: 0 errors. Fix any SettingsManager seam problems exposed above.

- [ ] **Step 5: Commit**

```bash
git add lib/screens/projects/
git commit -m "feat(projects): add project detail screen (docs/upload/active/settings/ask)"
```

---

### Task 15: Active project chip on HomeScreen

**Files:**
- Modify: `lib/screens/home_screen.dart`
- Create: `lib/widgets/active_project_chip.dart`

- [ ] **Step 1: Create the chip widget**

Create `lib/widgets/active_project_chip.dart`:

```dart
// ABOUTME: Compact chip showing the active-for-live project; taps open picker.

import 'package:flutter/material.dart';

import '../services/database/helix_database.dart';
import '../services/projects/active_project_controller.dart';
import '../services/projects/projects_service.dart';
import '../theme/helix_theme.dart';

class ActiveProjectChip extends StatelessWidget {
  const ActiveProjectChip({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<String?>(
      stream: ActiveProjectController.instance.activeProjectStream,
      initialData: ActiveProjectController.instance.activeProjectId,
      builder: (ctx, activeSnap) {
        final activeId = activeSnap.data;
        return StreamBuilder<List<Project>>(
          stream: ProjectsService.instance.watchProjects(),
          initialData: const [],
          builder: (ctx, projSnap) {
            final projects = projSnap.data ?? const [];
            final active = activeId == null
                ? null
                : projects.firstWhere((p) => p.id == activeId,
                    orElse: () => projects.isEmpty
                        ? Project(
                            id: activeId,
                            name: '(unavailable)',
                            description: null,
                            createdAt: 0,
                            updatedAt: 0,
                            deletedAt: null,
                            chunkSizeTokens: 800,
                            chunkOverlapTokens: 100,
                            retrievalTopK: 5,
                            retrievalMinSimilarity: 0.3)
                        : projects.first);
            final label =
                active == null ? 'No project' : 'Project: ${active.name}';
            return GestureDetector(
              onTap: () => _showPicker(context, projects, activeId),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                      color: active != null
                          ? HelixTheme.cyan
                          : HelixTheme.textMuted.withOpacity(0.3)),
                  color: active != null
                      ? HelixTheme.cyan.withOpacity(0.08)
                      : null,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(active != null ? Icons.star : Icons.star_border,
                        size: 16,
                        color: active != null
                            ? HelixTheme.cyan
                            : HelixTheme.textMuted),
                    const SizedBox(width: 6),
                    Text(label,
                        style: const TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _showPicker(
      BuildContext context, List<Project> projects, String? activeId) async {
    await showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            ListTile(
              leading: const Icon(Icons.clear),
              title: const Text('No project'),
              trailing: activeId == null ? const Icon(Icons.check) : null,
              onTap: () async {
                await ActiveProjectController.instance.setActive(null);
                if (context.mounted) Navigator.pop(ctx);
              },
            ),
            const Divider(height: 1),
            for (final p in projects)
              ListTile(
                leading: const Icon(Icons.folder_outlined),
                title: Text(p.name),
                trailing:
                    p.id == activeId ? const Icon(Icons.check) : null,
                onTap: () async {
                  await ActiveProjectController.instance.setActive(p.id);
                  if (context.mounted) Navigator.pop(ctx);
                },
              ),
            if (projects.isEmpty)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                    'No projects yet. Create one in the Projects tab.'),
              ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Place the chip on HomeScreen**

Find an appropriate location in `lib/screens/home_screen.dart` — near the top of the main content column, above the transcript area. Typical insertion: inside the primary `Column` that wraps home content, after the app-bar-equivalent header.

Run:

```bash
grep -n "AppBar\|SliverAppBar\|Column(" lib/screens/home_screen.dart | head -10
```

Insert this widget at a clean seam (look for an existing horizontally-aligned `Row` of mode/preset controls — place the chip next to them):

```dart
import '../widgets/active_project_chip.dart';
```

Then add a `Padding(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4), child: Align(alignment: Alignment.centerLeft, child: ActiveProjectChip()))` as a child of the top-level column. Exact placement is at the implementer's discretion — match existing HomeScreen padding and spacing conventions.

- [ ] **Step 3: Run analyze**

```bash
flutter analyze
```

Expected: 0 errors.

- [ ] **Step 4: Commit**

```bash
git add lib/widgets/active_project_chip.dart lib/screens/home_screen.dart
git commit -m "feat(projects): add active-project chip to HomeScreen"
```

---

### Task 16: Surface project citations in live answer area

**Files:**
- Modify: `lib/screens/home_screen.dart`

- [ ] **Step 1: Subscribe to citations and render a strip**

In `lib/screens/home_screen.dart`, locate the `StreamBuilder` that subscribes to `ConversationEngine.instance.aiResponseStream` (grep:

```bash
grep -n "aiResponseStream\|_answerText\|_currentAnswer" lib/screens/home_screen.dart | head -10
```

Near that widget, add a parallel `StreamBuilder<List<RetrievedChunk>>` that listens to `ConversationEngine.instance.projectCitationsStream` and renders a horizontal `Wrap` of tappable chips below the answer.

Example widget to paste alongside the answer area:

```dart
StreamBuilder<List<RetrievedChunk>>(
  stream: ConversationEngine.instance.projectCitationsStream,
  initialData: const [],
  builder: (_, snap) {
    final chunks = snap.data ?? const [];
    if (chunks.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Wrap(
        spacing: 6,
        children: [
          for (var i = 0; i < chunks.length; i++)
            ActionChip(
              label: Text(
                  '[${i + 1}] ${chunks[i].documentFilename}'
                  '${chunks[i].pageStart != null ? ' p.${chunks[i].pageStart}' : ''}',
                  style: const TextStyle(fontSize: 11)),
              onPressed: () => showDialog(
                context: context,
                builder: (_) => AlertDialog(
                  title: Text(chunks[i].documentFilename),
                  content: SingleChildScrollView(
                      child: SelectableText(chunks[i].chunkText)),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Close')),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  },
),
```

Add imports at the top if missing:

```dart
import '../services/conversation_engine.dart';
import '../services/projects/project_rag_service.dart';
```

- [ ] **Step 2: Run analyze**

```bash
flutter analyze
```

Expected: 0 errors.

- [ ] **Step 3: Commit**

```bash
git add lib/screens/home_screen.dart
git commit -m "feat(projects): show citation chips under live answer"
```

---

## Final validation

### Task 17: Run the full validation gate

- [ ] **Step 1: Regenerate any out-of-date Drift code**

```bash
dart run build_runner build --delete-conflicting-outputs
```

- [ ] **Step 2: Analyze**

```bash
flutter analyze
```

Expected: 0 errors.

- [ ] **Step 3: All unit + widget tests**

```bash
flutter test test/
```

Expected: all pass. If you see failures in `test/services/conversation_engine_*_test.dart` that relate to the `_projectCitationsController` insertion, confirm the engine still closes it on dispose and that no test expects a precise controller count.

- [ ] **Step 4: Simulator build**

```bash
flutter build ios --simulator --no-codesign
```

Expected: builds successfully.

- [ ] **Step 5: Full gate if any listed files changed**

Per `CLAUDE.md`, if any of the listed files changed (`conversation_engine.dart` did — we modified it), run:

```bash
bash scripts/run_gate.sh
```

Expected: all gates pass.

- [ ] **Step 6: Commit any gate-driven fixes** (if none, skip)

---

### Task 18: Manual simulator smoke test

Manual — **the engineer must do this before marking work complete**.

- [ ] Boot a dedicated Helix simulator (not the shared ones — see CLAUDE.md).
- [ ] Ensure an OpenAI API key is configured in Settings.
- [ ] Open Projects tab → Create new project "Smoke Test" → open it.
- [ ] Upload a small TXT (e.g., a file that contains the phrase "The magic number is 42") and confirm document transitions pending → processing → ready. (A stubbed short TXT with a non-trivial unique fact is fastest.)
- [ ] Upload a small PDF of 2–3 pages and confirm it reaches `ready`. Note the page count.
- [ ] Tap "Ask this project", ask "What is the magic number?", confirm the answer cites `[1]` and source matches the TXT.
- [ ] Return to Home screen. Confirm the active-project chip says "No project".
- [ ] Tap the chip, pick "Smoke Test". Confirm the chip updates and persists across an app restart.
- [ ] Start a conversation and ask the magic-number question via voice. Confirm:
  - The generated answer references the fact.
  - Citation chips appear beneath the answer.
  - Tapping a chip shows the excerpt text.
- [ ] Delete the project from its detail screen. Confirm it moves to "Recently deleted" in the Projects tab, and the active-project chip falls back to "No project".
- [ ] Tap "Undo" in Recently deleted. Confirm the project returns.
- [ ] Restart the app. Confirm the restored project is still present.
- [ ] Record any issues. If nothing blocks, ship.

---

## Self-review checklist (writer only — already completed for you)

- **Spec coverage:**
  - Schema — Tasks 1, 2
  - Chunker — Task 3
  - Embedding math — Task 4
  - Embedding client — Task 5
  - ProjectsService — Task 6
  - DocumentIngestService (with the isolate deferred, flagged) — Task 7
  - ProjectRagService — Task 8
  - ActiveProjectController — Task 9
  - ConversationEngine hook + citations stream — Tasks 10, 11
  - App init (purge, active controller load) — Task 12
  - Projects tab on LiveHistoryScreen — Task 13
  - Project detail + upload + active toggle + settings + Ask — Task 14
  - Home screen active chip — Task 15
  - Live citations UI — Task 16
  - Gate — Task 17
  - Smoke test — Task 18

- **Placeholder scan:** No TBD/TODO/"similar to Task N" remaining. File paths are exact. Code is provided in full where it matters.

- **Type consistency spot-check:**
  - `ChunkToPersist` defined in `project_dao.dart`, consumed in `document_ingest_service.dart`.
  - `RetrievedChunk` defined in `project_rag_service.dart`, consumed in `project_context_formatter.dart`, `conversation_engine.dart`, `project_ask_dialog.dart`, and `home_screen.dart`.
  - `EmbeddingClient` interface defined in `openai_embeddings_client.dart`, implemented by `OpenAiEmbeddingsClient`, used by `DocumentIngestService` and `ProjectRagService`.
  - `IngestEvent` variants referenced identically in service and UI.
  - `ActiveProjectController.load()` / `.instance` / `.resetForTesting()` — consistent across tests and callers.

- **Risks flagged:**
  - `SettingsManager.instance.cachedOpenAiApiKey` may not exist as a sync getter; Task 14 Step 3 includes the remediation path. The engineer should adjust if required.
  - `ConversationEngine._nextResponseToken` and `askDirectForTesting` seam: the engineer may need to adapt to the engine's existing test helpers if the proposed helper conflicts. Task 11 Step 3 calls this out.
  - `path_provider_platform_interface` may not be a direct dependency; Task 7 Step 5 covers adding it if the test fails to compile.
