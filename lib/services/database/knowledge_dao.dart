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

  /// Insert or update an entity. On conflict, increments mentionCount and
  /// updates lastSeen / confidence.
  Future<void> upsertEntity(KnowledgeEntitiesCompanion entry) async {
    final existing = await (select(knowledgeEntities)
          ..where((e) => e.id.equals(entry.id.value)))
        .getSingleOrNull();

    if (existing != null) {
      await (update(knowledgeEntities)
            ..where((e) => e.id.equals(entry.id.value)))
          .write(KnowledgeEntitiesCompanion(
        mentionCount: Value(existing.mentionCount + 1),
        lastSeen: entry.lastSeen,
        confidence: entry.confidence,
        metadata: entry.metadata,
      ));
    } else {
      await into(knowledgeEntities).insert(entry);
    }
  }

  /// Find a single entity by exact name (case-insensitive).
  Future<KnowledgeEntity?> findEntityByName(String name) {
    return (select(knowledgeEntities)
          ..where(
              (e) => e.name.lower().equals(name.toLowerCase())))
        .getSingleOrNull();
  }

  /// Search entities whose name contains [query], ordered by mention count.
  Future<List<KnowledgeEntity>> searchEntities(String query) {
    return (select(knowledgeEntities)
          ..where((e) => e.name.like('%$query%'))
          ..orderBy([(e) => OrderingTerm.desc(e.mentionCount)])
          ..limit(20))
        .get();
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
  Future<UserProfile> getProfile() async {
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
  }

  /// Update the profile JSON, incrementing the version.
  Future<void> updateProfile(String profileJson) async {
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
  }
}
