// ABOUTME: Verifies ConversationEngine injects PROJECT CONTEXT into the system
// ABOUTME: prompt when an active project is set, and leaves it untouched otherwise.

import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_helix/services/conversation_engine.dart';
import 'package:flutter_helix/services/database/helix_database.dart';
import 'package:flutter_helix/services/database/project_dao.dart';
import 'package:flutter_helix/services/projects/active_project_controller.dart';
import 'package:flutter_helix/services/projects/embedding_math.dart';
import 'package:flutter_helix/services/projects/openai_embeddings_client.dart';
import 'package:flutter_helix/services/projects/project_rag_service.dart';

import '../helpers/test_helpers.dart';

class _StaticEmbeddings implements EmbeddingClient {
  _StaticEmbeddings(this.vector);
  final Float32List vector;
  @override
  Future<EmbeddingBatchResult> embedBatch(List<String> inputs) async =>
      EmbeddingBatchResult(
        vectors: List.filled(inputs.length, vector),
        promptTokens: 0,
      );

  @override
  Future<Float32List> embed(String input) async => vector;
}

Future<String> _seedProjectWithChunk({
  required HelixDatabase db,
  required String chunkText,
  required Float32List vector,
}) async {
  final project = await db.projectDao.createProject(name: 'Test Project');
  final doc = await db.projectDao.insertDocument(
    projectId: project.id,
    filename: 'Q3.pdf',
    contentType: 'pdf',
    byteSize: 1024,
  );
  await db.projectDao.saveChunksAndVectors(
    documentId: doc.id,
    projectId: project.id,
    chunks: [
      ChunkToPersist(chunkIndex: 0, text: chunkText, tokenCount: 10),
    ],
    vectors: [EmbeddingMath.encodeVector(vector)],
    embeddingModel: 'text-embedding-3-small',
  );
  await db.projectDao
      .updateDocumentStatus(doc.id, status: 'ready', pageCount: 1);
  return project.id;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late HelixDatabase db;

  setUp(() async {
    installPlatformMocks();
    await initTestSettings();
    ConversationEngine.resetTestHooks();
    ActiveProjectController.resetForTesting();
    ProjectRagService.resetForTesting();
    // Load a fresh ActiveProjectController backed by the mock prefs.
    await ActiveProjectController.load();

    db = HelixDatabase.forTesting(NativeDatabase.memory());
    await HelixDatabase.overrideForTesting(db);

    ProjectRagService.initialize(
      db: db,
      embeddingClient: _StaticEmbeddings(Float32List.fromList([1, 0, 0])),
    );
  });

  tearDown(() async {
    ConversationEngine.instance.stop();
    ConversationEngine.instance.clearHistory();
    ProjectRagService.resetForTesting();
    ActiveProjectController.resetForTesting();
    await HelixDatabase.resetForTesting();
    await db.close();
    removePlatformMocks();
  });

  test(
    'injects PROJECT CONTEXT into system prompt when an active project is set',
    () async {
      const chunkText = 'Revenue was \$4.2M in Q3.';
      final projectId = await _seedProjectWithChunk(
        db: db,
        chunkText: chunkText,
        vector: Float32List.fromList([1, 0, 0]),
      );
      await ActiveProjectController.instance.setActive(projectId);

      final provider = await configureFakeLlm(
        streamResponses: const [
          FakeStreamResponse(['Q3 revenue was \$4.2M [1].']),
        ],
      );

      await ConversationEngine.instance.askQuestion('What was Q3 revenue?');

      // askQuestion invokes _generateResponse via streamResponse (captured
      // in streamResponse below); downstream fact-check may also call
      // getResponse with its own system prompt, so search across all.
      expect(provider.capturedSystemPrompts, isNotEmpty);
      final enrichedPrompt = provider.capturedSystemPrompts.firstWhere(
        (p) => p.contains('PROJECT CONTEXT'),
        orElse: () => '',
      );
      expect(enrichedPrompt, contains('PROJECT CONTEXT'),
          reason: 'no captured system prompt contained PROJECT CONTEXT');
      expect(enrichedPrompt, contains(chunkText));
      expect(enrichedPrompt, contains('Q3.pdf'));
    },
  );

  test(
    'does NOT inject PROJECT CONTEXT when no project is active',
    () async {
      // Seed a project but do NOT call setActive — active project stays null.
      await _seedProjectWithChunk(
        db: db,
        chunkText: 'Revenue was \$4.2M in Q3.',
        vector: Float32List.fromList([1, 0, 0]),
      );

      final provider = await configureFakeLlm(
        streamResponses: const [
          FakeStreamResponse(['general answer']),
        ],
      );

      await ConversationEngine.instance.askQuestion('What was Q3 revenue?');

      expect(provider.capturedSystemPrompts, isNotEmpty);
      for (final prompt in provider.capturedSystemPrompts) {
        expect(prompt, isNot(contains('PROJECT CONTEXT')));
      }
    },
  );
}
