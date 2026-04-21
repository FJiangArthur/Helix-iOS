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
  // ignore: unused_element_parameter
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
    // Either no doc row (rejected pre-insert) or one with failed status
    // Plan specifies failure yields no document row (doc argument in IngestFailed may be null)
    expect(docs, hasLength(lessThanOrEqualTo(1)));
    if (docs.isNotEmpty) {
      expect(docs.single.ingestError, contains('10 MB'));
    }
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
