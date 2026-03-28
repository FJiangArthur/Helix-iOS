import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../utils/app_logger.dart';
import 'database/helix_database.dart';

/// Persistent in-memory store for named entities (people, companies) mentioned
/// during conversations.  Data is persisted to the SQLite facts table (V2.2).
class EntityMemory {
  static EntityMemory? _instance;
  static EntityMemory get instance => _instance ??= EntityMemory._();
  EntityMemory._();

  static const _uuid = Uuid();

  final Map<String, EntityInfo> _entities = {};

  void addEntity(EntityInfo entity) {
    _entities[entity.name.toLowerCase()] = entity;
    // Also persist to facts table (fire-and-forget)
    _persistEntityAsFact(entity);
  }

  EntityInfo? lookup(String name) => _entities[name.toLowerCase()];

  List<EntityInfo> get all => _entities.values.toList();

  /// Persist all entities to SQLite.
  ///
  /// In V2.2 individual entities are written on [addEntity], so this is
  /// largely a no-op.  It is kept for API compatibility with callers that
  /// still invoke `save()` after batch mutations.
  Future<void> save() async {
    appLogger
        .d('[EntityMemory] save() called — entities persist via facts table');
  }

  /// Load entities from the SQLite facts table (biographical category).
  Future<void> load() async {
    try {
      final db = HelixDatabase.instance;
      final facts =
          await db.factsDao.getConfirmedFacts(category: 'biographical');
      for (final fact in facts) {
        final name = _extractNameFromFact(fact.content);
        if (name.isNotEmpty) {
          _entities[name.toLowerCase()] = EntityInfo(
            name: name,
            context: fact.content,
            lastMentioned:
                DateTime.fromMillisecondsSinceEpoch(fact.createdAt),
          );
        }
      }
      appLogger
          .d('[EntityMemory] Loaded ${_entities.length} entities from facts table');
    } catch (e) {
      appLogger.e('[EntityMemory] Failed to load from facts table: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  Future<void> _persistEntityAsFact(EntityInfo entity) async {
    try {
      final db = HelixDatabase.instance;
      final dedupeKey = entity.name.toLowerCase().trim();
      final existing = await db.factsDao.getFactsByDedupeKey(dedupeKey);
      if (existing.isEmpty) {
        await db.factsDao.insertFact(
          FactsCompanion.insert(
            id: _uuid.v4(),
            category: 'biographical',
            content: _buildContent(entity),
            status: const Value('confirmed'),
            confidence: const Value(0.8),
            dedupeKey: Value(dedupeKey),
            createdAt: DateTime.now().millisecondsSinceEpoch,
          ),
        );
      }
    } catch (e) {
      appLogger.e('[EntityMemory] Failed to persist entity: $e');
    }
  }

  static String _buildContent(EntityInfo entity) {
    final parts = <String>[entity.name];
    if (entity.title != null && entity.title!.isNotEmpty) {
      parts.add('(${entity.title})');
    }
    if (entity.company != null && entity.company!.isNotEmpty) {
      parts.add('at ${entity.company}');
    }
    if (entity.context != null && entity.context!.isNotEmpty) {
      parts.add('— ${entity.context}');
    }
    return parts.join(' ');
  }

  /// Best-effort extraction of the entity name from a fact content string.
  /// Content format: "Name (Title) at Company — context"
  static String _extractNameFromFact(String content) {
    // Name is always the first token(s) before '(' or 'at ' or '—'
    final trimmed = content.trim();
    for (final delimiter in ['(', ' at ', ' —']) {
      final idx = trimmed.indexOf(delimiter);
      if (idx > 0) return trimmed.substring(0, idx).trim();
    }
    // No delimiter found — the whole string is the name (single-word entity)
    return trimmed;
  }
}

class EntityInfo {
  final String name;
  final String? title;
  final String? company;
  final String? context;
  final DateTime lastMentioned;

  EntityInfo({
    required this.name,
    this.title,
    this.company,
    this.context,
    required this.lastMentioned,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        if (title != null) 'title': title,
        if (company != null) 'company': company,
        if (context != null) 'context': context,
        'lastMentioned': lastMentioned.toIso8601String(),
      };

  factory EntityInfo.fromJson(Map<String, dynamic> json) => EntityInfo(
        name: json['name'] as String? ?? '',
        title: json['title'] as String?,
        company: json['company'] as String?,
        context: json['context'] as String?,
        lastMentioned: json['lastMentioned'] != null
            ? DateTime.tryParse(json['lastMentioned'] as String) ??
                DateTime.now()
            : DateTime.now(),
      );
}
