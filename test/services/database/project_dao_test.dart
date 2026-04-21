import 'dart:typed_data';

import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_helix/services/database/helix_database.dart';
import 'package:flutter_helix/services/database/project_dao.dart';

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

    test('undoDelete bumps updatedAt so restored project floats to top',
        () async {
      final p1 = await db.projectDao.createProject(name: 'old');
      await Future<void>.delayed(const Duration(milliseconds: 2));
      final p2 = await db.projectDao.createProject(name: 'newer');
      await db.projectDao.softDeleteProject(p1.id);
      await Future<void>.delayed(const Duration(milliseconds: 2));
      await db.projectDao.undoDelete(p1.id);
      final rows = await db.projectDao.watchActiveProjects().first;
      // p1 should now be first (most recently updated)
      expect(rows.first.id, p1.id);
      expect(rows.last.id, p2.id);
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
              text_: 't',
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

    test('updateDocumentStatus transitions pending -> ready', () async {
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
