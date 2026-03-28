import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../../utils/app_logger.dart';
import 'helix_database.dart';

/// One-time migration from SharedPreferences to SQLite (V2.2).
class MigrationService {
  static const _migrationKey = 'migration_v22_complete';
  static const _uuid = Uuid();

  /// Run migration if needed. Returns true if migration was performed.
  static Future<bool> migrateIfNeeded() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_migrationKey) == true) {
      return false;
    }

    appLogger
        .i('[Migration] Starting V2.2 SharedPreferences -> SQLite migration');
    final db = HelixDatabase.instance;

    // Migrate conversation history
    await _migrateConversationHistory(prefs, db);

    // Migrate entity memory
    await _migrateEntityMemory(prefs, db);

    await prefs.setBool(_migrationKey, true);
    appLogger.i('[Migration] V2.2 migration complete');
    return true;
  }

  static Future<void> _migrateConversationHistory(
    SharedPreferences prefs,
    HelixDatabase db,
  ) async {
    final raw = prefs.getString('conversation_history');
    if (raw == null || raw.isEmpty) return;

    try {
      final jsonList = jsonDecode(raw) as List<dynamic>;
      if (jsonList.isEmpty) return;

      // Create a single conversation for the legacy history
      final conversationId = _uuid.v4();
      final now = DateTime.now().millisecondsSinceEpoch;

      await db.conversationDao.insertConversation(
        ConversationsCompanion.insert(
          id: conversationId,
          startedAt: now - (jsonList.length * 60000), // rough estimate
          endedAt: Value(now),
          title: const Value('Migrated conversation history'),
          isProcessed: const Value(true),
        ),
      );

      // Insert each turn as a segment
      for (int i = 0; i < jsonList.length; i++) {
        final turn = jsonList[i] as Map<String, dynamic>;
        final content = turn['content'] as String? ?? '';
        final role = turn['role'] as String? ?? 'user';

        await db.conversationDao.insertSegment(
          ConversationSegmentsCompanion.insert(
            id: _uuid.v4(),
            conversationId: conversationId,
            segmentIndex: i,
            text_: content,
            speakerLabel: Value(role == 'user' ? 'me' : 'assistant'),
            startedAt: now - ((jsonList.length - i) * 60000),
          ),
        );
      }

      // Remove old key
      await prefs.remove('conversation_history');
      appLogger.i('[Migration] Migrated ${jsonList.length} conversation turns');
    } catch (e) {
      appLogger.e('[Migration] Failed to migrate conversation history',
          error: e);
    }
  }

  static Future<void> _migrateEntityMemory(
    SharedPreferences prefs,
    HelixDatabase db,
  ) async {
    final raw = prefs.getString('entity_memory');
    if (raw == null || raw.isEmpty) return;

    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      for (final item in decoded) {
        if (item is Map<String, dynamic>) {
          final name = item['name'] as String? ?? '';
          if (name.isEmpty) continue;

          // Migrate entities as facts with category 'biographical'
          final content = _buildEntityFactContent(item);
          await db.factsDao.insertFact(
            FactsCompanion.insert(
              id: _uuid.v4(),
              category: 'biographical',
              content: content,
              status: const Value('confirmed'),
              confidence: const Value(0.8),
              dedupeKey: Value(name.toLowerCase().trim()),
              createdAt: DateTime.now().millisecondsSinceEpoch,
            ),
          );
        }
      }

      await prefs.remove('entity_memory');
      appLogger.i('[Migration] Migrated ${decoded.length} entities to facts');
    } catch (e) {
      appLogger.e('[Migration] Failed to migrate entity memory', error: e);
    }
  }

  static String _buildEntityFactContent(Map<String, dynamic> entity) {
    final name = entity['name'] as String? ?? '';
    final title = entity['title'] as String?;
    final company = entity['company'] as String?;
    final context = entity['context'] as String?;

    final parts = <String>[name];
    if (title != null && title.isNotEmpty) parts.add('($title)');
    if (company != null && company.isNotEmpty) parts.add('at $company');
    if (context != null && context.isNotEmpty) parts.add('— $context');
    return parts.join(' ');
  }
}
