// ABOUTME: Pipeline for ingesting a single document: extract -> chunk -> embed -> persist.
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
            null, 'Unsupported file type - only .pdf and .txt are allowed');
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
            'No text could be extracted - scanned PDFs require OCR which is not supported in v1');
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
