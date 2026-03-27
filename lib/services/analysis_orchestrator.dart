import 'package:flutter_helix/services/analysis_backend.dart';
import 'package:flutter_helix/services/conversation_engine.dart';
import 'package:flutter_helix/services/knowledge_base.dart';
import 'package:flutter_helix/utils/app_logger.dart';

/// Orchestrates the analysis pipeline: calls an [AnalysisProvider], then merges
/// extracted facts, relationships, and profile updates into the
/// [UserKnowledgeBase].
class AnalysisOrchestrator {
  AnalysisOrchestrator({required this.kb, required this.provider});

  final UserKnowledgeBase kb;
  final AnalysisProvider provider;

  /// Maps relationship types to the implied entity type for entity B.
  static const _relationToEntityType = <String, String>{
    'works_at': 'company',
    'founded': 'company',
    'located_in': 'place',
    'lives_in': 'place',
  };

  /// Regular expression that matches the first sequence of capitalised words
  /// in a string (e.g. "John Smith is an engineer" → "John Smith").
  static final _capitalizedNameRe =
      RegExp(r'\b([A-Z][a-z]+(?:\s+[A-Z][a-z]+)*)');

  /// Analyse [segments] via the configured provider and merge results into the
  /// knowledge base.
  Future<void> processSegments(List<TranscriptSegment> segments) async {
    if (segments.isEmpty) return;

    // 1. Current profile for context.
    final profileJson = await kb.getProfile();

    // 2. Run analysis.
    final result = await provider.analyze(
      segments: segments,
      userProfileJson: profileJson,
    );

    int factsAdded = 0;
    int relationshipsAdded = 0;
    bool profileUpdated = false;

    // 3. Merge facts — biographical/relationship facts create entities.
    for (final fact in result.facts) {
      if (fact.category == 'biographical' || fact.category == 'relationship') {
        final match = _capitalizedNameRe.firstMatch(fact.content);
        if (match != null) {
          final entityName = match.group(1)!;
          await kb.addOrUpdateEntity(
            name: entityName,
            type: 'person',
            source: 'analysis',
          );
          factsAdded++;
        }
      }
    }

    // 4. Merge relationships.
    for (final rel in result.relationships) {
      final entityBType = _relationToEntityType[rel.type] ?? 'person';

      // Ensure both entities exist.
      await kb.addOrUpdateEntity(
        name: rel.entityA,
        type: 'person',
        source: 'analysis',
      );
      await kb.addOrUpdateEntity(
        name: rel.entityB,
        type: entityBType,
        source: 'analysis',
      );

      // Look up IDs.
      final entityA = await kb.findEntity(rel.entityA);
      final entityB = await kb.findEntity(rel.entityB);

      if (entityA != null && entityB != null) {
        await kb.addRelationship(
          entityAId: entityA.id,
          entityBId: entityB.id,
          relationType: rel.type,
          description: rel.description,
        );
        relationshipsAdded++;
      }
    }

    // 5. Merge profile updates.
    if (result.profileUpdates.isNotEmpty) {
      await kb.updateProfile(result.profileUpdates);
      profileUpdated = true;
    }

    // 6. Log summary.
    appLogger.d(
      'AnalysisOrchestrator: merged $factsAdded facts, '
      '$relationshipsAdded relationships, '
      'profile ${profileUpdated ? "updated" : "unchanged"}',
    );
  }
}
