// ABOUTME: Retrieval layer for Buzz AI chat — searches FTS5 indices and
// ABOUTME: enriches results with surrounding conversation context.

import 'package:flutter_helix/services/database/helix_database.dart';
import 'package:flutter_helix/services/database/search_dao.dart';
import 'package:flutter_helix/utils/app_logger.dart';

/// A search result enriched with surrounding context.
class BuzzSearchResult {
  final String sourceType; // 'segment' or 'fact'
  final String sourceId;
  final String? conversationId;
  final String matchedText;
  final String? context; // surrounding segments for conversation results
  final double relevanceScore;
  final DateTime? timestamp;

  const BuzzSearchResult({
    required this.sourceType,
    required this.sourceId,
    this.conversationId,
    required this.matchedText,
    this.context,
    required this.relevanceScore,
    this.timestamp,
  });
}

/// Performs retrieval for Buzz queries using FTS5 full-text search
/// and enriches segment results with surrounding conversation context.
class BuzzSearchService {
  static BuzzSearchService? _instance;
  static BuzzSearchService get instance => _instance ??= BuzzSearchService._();
  BuzzSearchService._();

  /// Search across all content types using FTS5.
  /// Returns ranked results with context, capped at [limit].
  Future<List<BuzzSearchResult>> search(String query, {int limit = 20}) async {
    final db = HelixDatabase.instance;

    // Sanitize the query for FTS5 — remove special characters that break MATCH.
    final sanitized = _sanitizeFtsQuery(query);
    if (sanitized.isEmpty) return [];

    List<SearchResult> results;
    try {
      results = await db.searchDao.searchAll(sanitized);
    } catch (e, st) {
      appLogger.e('[BuzzSearch] FTS5 query failed', error: e, stackTrace: st);
      return [];
    }

    if (results.length > limit) {
      results = results.sublist(0, limit);
    }

    final enriched = <BuzzSearchResult>[];

    for (final r in results) {
      if (r.type == 'segment') {
        final context = await _loadSegmentContext(db, r);
        enriched.add(BuzzSearchResult(
          sourceType: r.type,
          sourceId: r.id,
          conversationId: r.conversationId,
          matchedText: r.text,
          context: context,
          relevanceScore: r.rank,
          timestamp: await _segmentTimestamp(db, r),
        ));
      } else {
        // Fact result — include content directly.
        enriched.add(BuzzSearchResult(
          sourceType: r.type,
          sourceId: r.id,
          conversationId: r.conversationId,
          matchedText: r.text,
          context: null,
          relevanceScore: r.rank,
        ));
      }
    }

    appLogger.d(
      '[BuzzSearch] Found ${enriched.length} results '
      '(queryChars=${query.length})',
    );
    return enriched;
  }

  /// Load 2 segments before and after the matched segment for context.
  Future<String?> _loadSegmentContext(
    HelixDatabase db,
    SearchResult result,
  ) async {
    final convId = result.conversationId;
    if (convId == null) return null;

    try {
      final allSegments =
          await db.conversationDao.getSegmentsForConversation(convId);
      final idx = allSegments.indexWhere((s) => s.id == result.id);
      if (idx < 0) return null;

      final start = (idx - 2).clamp(0, allSegments.length);
      final end = (idx + 3).clamp(0, allSegments.length); // exclusive
      final window = allSegments.sublist(start, end);

      return window.map((s) {
        final prefix = s.speakerLabel != null ? '${s.speakerLabel}: ' : '';
        return '$prefix${s.text_}';
      }).join('\n');
    } catch (e) {
      appLogger.w('[BuzzSearch] Failed to load context for segment ${result.id}');
      return null;
    }
  }

  /// Retrieve the timestamp of a conversation segment.
  Future<DateTime?> _segmentTimestamp(
    HelixDatabase db,
    SearchResult result,
  ) async {
    final convId = result.conversationId;
    if (convId == null) return null;

    try {
      final segments =
          await db.conversationDao.getSegmentsForConversation(convId);
      final seg = segments.where((s) => s.id == result.id).firstOrNull;
      if (seg == null) return null;
      return DateTime.fromMillisecondsSinceEpoch(seg.startedAt);
    } catch (_) {
      return null;
    }
  }

  /// Strip characters that would break an FTS5 MATCH expression.
  String _sanitizeFtsQuery(String raw) {
    // Keep only alphanumeric, spaces, and basic CJK.
    return raw.replaceAll(RegExp(r'[^\w\s\u4e00-\u9fff]'), ' ').trim();
  }
}
