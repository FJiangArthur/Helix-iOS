import 'package:drift/drift.dart';

import 'helix_database.dart';

part 'knowledge_dao.g.dart';

const _defaultProfileJson =
    '{"identity":{"name":"","role":"","company":"","industry":"","languages":[]},'
    '"communicationStyle":{"formality":0.5,"verbosity":"balanced",'
    '"preferredResponseLanguage":"match_input","technicalDepth":"moderate"},'
    '"interests":[],"expertise":{},"currentFocus":"","socialGraph":[]}';

@DriftAccessor(tables: [KnowledgeEntities, KnowledgeRelationships, UserProfiles])
class KnowledgeDao extends DatabaseAccessor<HelixDatabase>
    with _$KnowledgeDaoMixin {
  KnowledgeDao(super.db);

  // ---------------------------------------------------------------------------
  // Knowledge Entities
  // ---------------------------------------------------------------------------

  /// Insert or update an entity atomically. On conflict, increments
  /// mentionCount and updates lastSeen / confidence / metadata.
  Future<void> upsertEntity(KnowledgeEntitiesCompanion entry) async {
    await customStatement(
      'INSERT INTO knowledge_entities '
      '(id, name, type, metadata, first_seen, last_seen, mention_count, confidence, source) '
      'VALUES (?1, ?2, ?3, ?4, ?5, ?6, 1, ?7, ?8) '
      'ON CONFLICT(id) DO UPDATE SET '
      'mention_count = mention_count + 1, '
      'last_seen = ?6, '
      'confidence = MIN(1.0, confidence + 0.1), '
      'metadata = COALESCE(?4, metadata)',
      [
        entry.id.value,
        entry.name.value,
        entry.type.value,
        entry.metadata.value,
        entry.firstSeen.value,
        entry.lastSeen.value,
        entry.confidence.value,
        entry.source.value,
      ],
    );
  }

  /// Find a single entity by exact name (case-insensitive).
  Future<KnowledgeEntity?> findEntityByName(String name) {
    return (select(knowledgeEntities)
          ..where(
              (e) => e.name.lower().equals(name.toLowerCase())))
        .getSingleOrNull();
  }

  /// Search entities whose name contains [query], ordered by mention count.
  /// Uses parameterized query to prevent SQL injection.
  Future<List<KnowledgeEntity>> searchEntities(String query) async {
    final results = await customSelect(
      'SELECT * FROM knowledge_entities '
      'WHERE name LIKE ?1 '
      'ORDER BY mention_count DESC '
      'LIMIT 20',
      variables: [Variable.withString('%$query%')],
      readsFrom: {knowledgeEntities},
    ).get();
    return results.map((row) => knowledgeEntities.map(row.data)).toList();
  }

  /// Top entities ordered by mention count descending.
  Future<List<KnowledgeEntity>> getTopEntities({int limit = 20}) {
    return (select(knowledgeEntities)
          ..orderBy([(e) => OrderingTerm.desc(e.mentionCount)])
          ..limit(limit))
        .get();
  }

  // ---------------------------------------------------------------------------
  // Knowledge Relationships
  // ---------------------------------------------------------------------------

  /// Insert a relationship, updating on conflict.
  Future<void> insertRelationship(KnowledgeRelationshipsCompanion entry) {
    return into(knowledgeRelationships).insertOnConflictUpdate(entry);
  }

  /// Get all relationships where [entityId] appears as either side.
  Future<List<KnowledgeRelationship>> getRelationshipsFor(String entityId) {
    return (select(knowledgeRelationships)
          ..where((r) =>
              r.entityAId.equals(entityId) | r.entityBId.equals(entityId)))
        .get();
  }

  // ---------------------------------------------------------------------------
  // User Profile
  // ---------------------------------------------------------------------------

  /// Get the user profile. If none exists, inserts a default and returns it.
  /// Wrapped in a transaction to prevent race conditions.
  Future<UserProfile> getProfile() async {
    return transaction(() async {
      final existing = await (select(userProfiles)
            ..where((p) => p.id.equals(1)))
          .getSingleOrNull();

      if (existing != null) return existing;

      final now = DateTime.now().millisecondsSinceEpoch;
      final companion = UserProfilesCompanion(
        id: const Value(1),
        profileJson: const Value(_defaultProfileJson),
        lastUpdated: Value(now),
        version: const Value(1),
      );
      await into(userProfiles).insert(companion);

      return (select(userProfiles)..where((p) => p.id.equals(1))).getSingle();
    });
  }

  /// Update the profile JSON, incrementing the version.
  /// Wrapped in a transaction to prevent race conditions.
  Future<void> updateProfile(String profileJson) async {
    return transaction(() async {
      final now = DateTime.now().millisecondsSinceEpoch;

      final existing = await (select(userProfiles)
            ..where((p) => p.id.equals(1)))
          .getSingleOrNull();

      if (existing != null) {
        await (update(userProfiles)..where((p) => p.id.equals(1))).write(
          UserProfilesCompanion(
            profileJson: Value(profileJson),
            lastUpdated: Value(now),
            version: Value(existing.version + 1),
          ),
        );
      } else {
        await into(userProfiles).insert(UserProfilesCompanion(
          id: const Value(1),
          profileJson: Value(profileJson),
          lastUpdated: Value(now),
          version: const Value(1),
        ));
      }
    });
  }
}
