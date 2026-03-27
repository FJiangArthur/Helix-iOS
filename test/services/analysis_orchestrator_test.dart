import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_helix/services/analysis_backend.dart';
import 'package:flutter_helix/services/analysis_orchestrator.dart';
import 'package:flutter_helix/services/conversation_engine.dart';
import 'package:flutter_helix/services/database/helix_database.dart';
import 'package:flutter_helix/services/knowledge_base.dart';

// ---------------------------------------------------------------------------
// Fakes
// ---------------------------------------------------------------------------

class FakeAnalysisProvider implements AnalysisProvider {
  BatchAnalysisResult nextResult = const BatchAnalysisResult();
  int callCount = 0;

  @override
  String get id => 'fake';

  @override
  String get displayName => 'Fake';

  @override
  bool get isAvailable => true;

  @override
  Future<BatchAnalysisResult> analyze({
    required List<TranscriptSegment> segments,
    required String userProfileJson,
  }) async {
    callCount++;
    return nextResult;
  }
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  late HelixDatabase db;
  late UserKnowledgeBase kb;
  late FakeAnalysisProvider fakeProvider;
  late AnalysisOrchestrator orchestrator;

  setUp(() {
    db = HelixDatabase.testWith(NativeDatabase.memory());
    kb = UserKnowledgeBase(db.knowledgeDao);
    fakeProvider = FakeAnalysisProvider();
    orchestrator = AnalysisOrchestrator(kb: kb, provider: fakeProvider);
  });

  tearDown(() async {
    await db.close();
  });

  List<TranscriptSegment> sampleSegments() => [
        TranscriptSegment(
          text: 'Hello, I work at Acme Corp.',
          timestamp: DateTime(2026, 3, 26),
        ),
      ];

  test('processSegments calls provider and merges facts into KB', () async {
    fakeProvider.nextResult = const BatchAnalysisResult(
      facts: [
        ExtractedFact(
          category: 'biographical',
          content: 'Alice Smith is an engineer',
          confidence: 0.9,
        ),
      ],
    );

    await orchestrator.processSegments(sampleSegments());

    expect(fakeProvider.callCount, 1);

    final entity = await kb.findEntity('Alice Smith');
    expect(entity, isNotNull);
    expect(entity!.type, 'person');
    expect(entity.source, 'analysis');
  });

  test('processSegments merges relationships', () async {
    fakeProvider.nextResult = const BatchAnalysisResult(
      relationships: [
        ExtractedRelationship(
          entityA: 'Bob',
          entityB: 'Acme Corp',
          type: 'works_at',
          description: 'Bob works at Acme Corp',
        ),
      ],
    );

    await orchestrator.processSegments(sampleSegments());

    // Both entities should have been created.
    final bob = await kb.findEntity('Bob');
    expect(bob, isNotNull);
    expect(bob!.type, 'person');

    final acme = await kb.findEntity('Acme Corp');
    expect(acme, isNotNull);
    expect(acme!.type, 'company');

    // Relationship should exist.
    final rels = await kb.getRelationshipsFor(bob.id);
    expect(rels, hasLength(1));
    expect(rels.first.relationType, 'works_at');
  });

  test('processSegments updates profile', () async {
    fakeProvider.nextResult = const BatchAnalysisResult(
      profileUpdates: {'identity': {'name': 'Alice'}},
    );

    await orchestrator.processSegments(sampleSegments());

    final profileJson = await kb.getProfile();
    final profile = jsonDecode(profileJson) as Map<String, dynamic>;
    final identity = profile['identity'] as Map<String, dynamic>?;
    expect(identity, isNotNull);
    expect(identity!['name'], 'Alice');
  });

  test('empty segments returns early without calling provider', () async {
    await orchestrator.processSegments([]);
    expect(fakeProvider.callCount, 0);
  });

  test('empty result merges nothing (no crash)', () async {
    fakeProvider.nextResult = const BatchAnalysisResult();

    await orchestrator.processSegments(sampleSegments());

    expect(fakeProvider.callCount, 1);
    // No entities should have been created.
    final top = await kb.getTopEntities(limit: 10);
    expect(top, isEmpty);
  });
}
