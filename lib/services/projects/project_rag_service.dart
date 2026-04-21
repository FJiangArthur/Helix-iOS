// ABOUTME: Retrieval API for Project RAG. Embeds query, ranks project chunks.
// ABOUTME: Returns top-K with source metadata for prompt injection + citations.

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
