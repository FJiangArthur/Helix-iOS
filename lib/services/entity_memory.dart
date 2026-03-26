import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Persistent in-memory store for named entities (people, companies) mentioned
/// during conversations.  Data is serialized to SharedPreferences as JSON.
class EntityMemory {
  static EntityMemory? _instance;
  static EntityMemory get instance => _instance ??= EntityMemory._();
  EntityMemory._();

  static const String _storageKey = 'entity_memory';

  final Map<String, EntityInfo> _entities = {};

  void addEntity(EntityInfo entity) {
    _entities[entity.name.toLowerCase()] = entity;
  }

  EntityInfo? lookup(String name) => _entities[name.toLowerCase()];

  List<EntityInfo> get all => _entities.values.toList();

  /// Persist all entities to SharedPreferences.
  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    final json = _entities.values.map((e) => e.toJson()).toList();
    await prefs.setString(_storageKey, jsonEncode(json));
  }

  /// Load entities from SharedPreferences.
  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw == null || raw.isEmpty) return;
    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      for (final item in decoded) {
        if (item is Map<String, dynamic>) {
          final entity = EntityInfo.fromJson(item);
          _entities[entity.name.toLowerCase()] = entity;
        }
      }
    } catch (_) {
      // Ignore corrupt data
    }
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
