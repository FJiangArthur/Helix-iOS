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
    expect(result.chunks.last.chunkText, 'c'); // similarity ~ 0.707
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
