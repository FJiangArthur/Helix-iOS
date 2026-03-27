import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import 'database/helix_database.dart';
import 'database/knowledge_dao.dart';

const _uuid = Uuid();

/// High-level service wrapping [KnowledgeDao] that provides entity/relationship
/// and profile management, plus context summary building for system prompts.
class UserKnowledgeBase {
  UserKnowledgeBase(this._dao);

  final KnowledgeDao _dao;

  // ---------------------------------------------------------------------------
  // Singleton
  // ---------------------------------------------------------------------------

  static UserKnowledgeBase? _instance;
  static UserKnowledgeBase get instance =>
      _instance ??= UserKnowledgeBase(HelixDatabase.instance.knowledgeDao);

  /// Reset singleton (for testing).
  static void resetInstance() => _instance = null;

  // ---------------------------------------------------------------------------
  // Entity management
  // ---------------------------------------------------------------------------

  /// Add or update a knowledge entity.
  ///
  /// If an entity with the same [name] already exists, its ID is reused so the
  /// DAO's upsert increments `mentionCount`. Empty/blank names are silently
  /// skipped.
  Future<void> addOrUpdateEntity({
    required String name,
    required String type,
    Map<String, dynamic>? metadata,
    required String source,
  }) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;

    final now = DateTime.now().millisecondsSinceEpoch;

    // Look up existing to reuse its ID (so upsert increments mentionCount).
    final existing = await _dao.findEntityByName(trimmed);
    final id = existing?.id ?? _uuid.v4();

    final metadataJson =
        metadata != null ? jsonEncode(metadata) : existing?.metadata;

    final companion = KnowledgeEntitiesCompanion(
      id: Value(id),
      name: Value(trimmed),
      type: Value(type),
      metadata: Value(metadataJson),
      firstSeen: Value(existing?.firstSeen ?? now),
      lastSeen: Value(now),
      confidence: Value(existing?.confidence ?? 0.5),
      source: Value(source),
    );

    await _dao.upsertEntity(companion);
  }

  /// Find an entity by exact name (case-insensitive).
  Future<KnowledgeEntity?> findEntity(String name) {
    return _dao.findEntityByName(name.trim());
  }

  /// Search entities whose name contains [query].
  Future<List<KnowledgeEntity>> searchEntities(String query) {
    return _dao.searchEntities(query.trim());
  }

  /// Top entities ordered by mention count descending.
  Future<List<KnowledgeEntity>> getTopEntities({int limit = 20}) {
    return _dao.getTopEntities(limit: limit);
  }

  // ---------------------------------------------------------------------------
  // Relationship management
  // ---------------------------------------------------------------------------

  /// Add a relationship between two entities.
  Future<void> addRelationship({
    required String entityAId,
    required String entityBId,
    required String relationType,
    String? description,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;

    final companion = KnowledgeRelationshipsCompanion.insert(
      id: _uuid.v4(),
      entityAId: entityAId,
      entityBId: entityBId,
      relationType: relationType,
      description: description != null ? Value(description) : const Value.absent(),
      firstSeen: now,
      lastSeen: now,
    );

    await _dao.insertRelationship(companion);
  }

  /// Get all relationships where [entityId] appears on either side.
  Future<List<KnowledgeRelationship>> getRelationshipsFor(String entityId) {
    return _dao.getRelationshipsFor(entityId);
  }

  // ---------------------------------------------------------------------------
  // User profile
  // ---------------------------------------------------------------------------

  /// Returns the profile JSON string.
  Future<String> getProfile() async {
    final profile = await _dao.getProfile();
    return profile.profileJson;
  }

  /// Deep-merges [updates] into the existing profile JSON and saves it back.
  Future<void> updateProfile(Map<String, dynamic> updates) async {
    final profile = await _dao.getProfile();
    final current =
        jsonDecode(profile.profileJson) as Map<String, dynamic>;
    final merged = _deepMerge(current, updates);
    await _dao.updateProfile(jsonEncode(merged));
  }

  // ---------------------------------------------------------------------------
  // Context building
  // ---------------------------------------------------------------------------

  /// Build a formatted context summary suitable for injection into system
  /// prompts. Returns an empty string when there is no useful data.
  Future<String> buildContextSummary({int maxTokens = 500}) async {
    final buf = StringBuffer();
    buf.writeln('[User Knowledge Context]');

    // Profile identity
    final profileJson = await getProfile();
    final profile = jsonDecode(profileJson) as Map<String, dynamic>;
    final identity = profile['identity'] as Map<String, dynamic>?;
    if (identity != null) {
      final name = identity['name'] as String? ?? '';
      final role = identity['role'] as String? ?? '';
      final company = identity['company'] as String? ?? '';
      final parts = <String>[
        if (name.isNotEmpty) 'Name: $name',
        if (role.isNotEmpty) 'Role: $role',
        if (company.isNotEmpty) 'Company: $company',
      ];
      if (parts.isNotEmpty) {
        buf.writeln(parts.join(', '));
      }
    }

    // Top people
    final allTop = await getTopEntities(limit: 20);
    final people =
        allTop.where((e) => e.type == 'person').take(5).toList();
    if (people.isNotEmpty) {
      buf.writeln('Key people:');
      for (final p in people) {
        final meta = _parseMetadata(p.metadata);
        final title = meta?['title'] ?? meta?['role'] ?? '';
        buf.writeln(
            '- ${p.name}${title.toString().isNotEmpty ? ' ($title)' : ''}');
      }
    }

    // Top companies
    final companies =
        allTop.where((e) => e.type == 'company').take(3).toList();
    if (companies.isNotEmpty) {
      buf.writeln('Key companies:');
      for (final c in companies) {
        buf.writeln('- ${c.name}');
      }
    }

    return buf.toString().trim();
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  /// Recursively deep-merges [overlay] into [base]. Nested maps merge
  /// recursively; all other values from [overlay] overwrite [base].
  Map<String, dynamic> _deepMerge(
      Map<String, dynamic> base, Map<String, dynamic> overlay) {
    final result = Map<String, dynamic>.from(base);
    for (final key in overlay.keys) {
      final baseVal = result[key];
      final overlayVal = overlay[key];
      if (baseVal is Map<String, dynamic> &&
          overlayVal is Map<String, dynamic>) {
        result[key] = _deepMerge(baseVal, overlayVal);
      } else {
        result[key] = overlayVal;
      }
    }
    return result;
  }

  Map<String, dynamic>? _parseMetadata(String? json) {
    if (json == null || json.isEmpty) return null;
    try {
      return jsonDecode(json) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }
}
