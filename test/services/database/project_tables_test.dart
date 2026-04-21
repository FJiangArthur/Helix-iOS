import 'dart:typed_data';

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
            text_: 'hello',
            tokenCount: 1));
    await db.into(db.projectDocumentChunkVectors).insert(
        ProjectDocumentChunkVectorsCompanion.insert(
            chunkId: 'c1',
            embedding: Uint8List(1536 * 4),
            embeddingModel: 'text-embedding-3-small'));

    expect((await db.select(db.projectDocuments).get()).single.filename, 'f.txt');
    expect((await db.select(db.projectDocumentChunks).get()).single.text_, 'hello');
    expect(
        (await db.select(db.projectDocumentChunkVectors).get()).single.chunkId,
        'c1');
  });
}
