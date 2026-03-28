// ABOUTME: Plain Dart model for daily memory entries.
// ABOUTME: Wraps the drift-generated DailyMemory data class with parsed themes/conversationIds.

import 'dart:convert';

import '../services/database/helix_database.dart';

class DailyMemoryModel {
  final String id;
  final String date; // ISO date string (YYYY-MM-DD)
  final String narrative;
  final List<String> themes;
  final List<String> conversationIds;
  final DateTime generatedAt;

  const DailyMemoryModel({
    required this.id,
    required this.date,
    required this.narrative,
    this.themes = const [],
    this.conversationIds = const [],
    required this.generatedAt,
  });

  /// Create from a drift-generated [DailyMemory] row.
  factory DailyMemoryModel.fromDrift(DailyMemory row) {
    List<String> parseJsonList(String raw) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          return decoded.cast<String>();
        }
      } catch (_) {}
      return [];
    }

    return DailyMemoryModel(
      id: row.id,
      date: row.date,
      narrative: row.narrative,
      themes: parseJsonList(row.themes),
      conversationIds: parseJsonList(row.conversationIds),
      generatedAt: DateTime.fromMillisecondsSinceEpoch(row.generatedAt),
    );
  }
}
