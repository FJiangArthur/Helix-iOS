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
    await (update(projects)..where((p) => p.id.equals(id))).write(
        ProjectsCompanion(deletedAt: Value(now), updatedAt: Value(now)));
  }

  Future<void> undoDelete(String id) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await (update(projects)..where((p) => p.id.equals(id))).write(
        ProjectsCompanion(deletedAt: const Value(null), updatedAt: Value(now)));
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
