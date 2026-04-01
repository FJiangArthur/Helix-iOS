import 'package:drift/drift.dart';

import 'helix_database.dart';

part 'conversation_dao.g.dart';

@DriftAccessor(
  tables: [
    Conversations,
    ConversationSegments,
    ConversationAiCostEntries,
    Topics,
  ],
)
class ConversationDao extends DatabaseAccessor<HelixDatabase>
    with _$ConversationDaoMixin {
  ConversationDao(super.db);

  /// Insert a new conversation row.
  Future<void> insertConversation(ConversationsCompanion entry) {
    return into(conversations).insert(entry);
  }

  /// Update an existing conversation.
  Future<bool> updateConversation(ConversationsCompanion entry) {
    return (update(conversations)..where((c) => c.id.equals(entry.id.value)))
        .write(entry)
        .then((rows) => rows > 0);
  }

  /// Watch a single conversation by id.
  Stream<Conversation> watchConversation(String id) {
    return (select(conversations)..where((c) => c.id.equals(id))).watchSingle();
  }

  /// Get conversations that started on a given calendar date.
  Future<List<Conversation>> getConversationsForDate(DateTime date) {
    final startOfDay = DateTime(
      date.year,
      date.month,
      date.day,
    ).millisecondsSinceEpoch;
    final endOfDay = DateTime(
      date.year,
      date.month,
      date.day + 1,
    ).millisecondsSinceEpoch;
    return (select(conversations)
          ..where(
            (c) =>
                c.startedAt.isBiggerOrEqualValue(startOfDay) &
                c.startedAt.isSmallerThanValue(endOfDay),
          )
          ..orderBy([(c) => OrderingTerm.desc(c.startedAt)]))
        .get();
  }

  /// Paginated list of all conversations (newest first).
  Future<List<Conversation>> getAllConversations({
    int limit = 50,
    int offset = 0,
  }) {
    return (select(conversations)
          ..orderBy([(c) => OrderingTerm.desc(c.startedAt)])
          ..limit(limit, offset: offset))
        .get();
  }

  /// Conversations that haven't been processed by the AI pipeline yet.
  Future<List<Conversation>> getUnprocessedConversations() {
    return (select(conversations)
          ..where((c) => c.isProcessed.equals(false))
          ..orderBy([(c) => OrderingTerm.asc(c.startedAt)]))
        .get();
  }

  // ---------------------------------------------------------------------------
  // Segments
  // ---------------------------------------------------------------------------

  /// Insert a new conversation segment.
  Future<void> insertSegment(ConversationSegmentsCompanion entry) {
    return into(conversationSegments).insert(entry);
  }

  /// All segments for a conversation, ordered by index.
  Future<List<ConversationSegment>> getSegmentsForConversation(
    String conversationId,
  ) {
    return (select(conversationSegments)
          ..where((s) => s.conversationId.equals(conversationId))
          ..orderBy([(s) => OrderingTerm.asc(s.segmentIndex)]))
        .get();
  }

  Future<double> getTotalAiCostUsd(String conversationId) async {
    final totalExpression = conversationAiCostEntries.costUsd.sum();
    final row =
        await (selectOnly(conversationAiCostEntries)
              ..addColumns([totalExpression])
              ..where(
                conversationAiCostEntries.conversationId.equals(conversationId),
              ))
            .getSingle();
    return row.read(totalExpression) ?? 0;
  }

  Future<Map<String, double>> getAiCostTotalsForConversationIds(
    List<String> conversationIds,
  ) async {
    if (conversationIds.isEmpty) return const {};

    final totalExpression = conversationAiCostEntries.costUsd.sum();
    final rows =
        await (selectOnly(conversationAiCostEntries)
              ..addColumns([
                conversationAiCostEntries.conversationId,
                totalExpression,
              ])
              ..where(
                conversationAiCostEntries.conversationId.isIn(conversationIds),
              )
              ..groupBy([conversationAiCostEntries.conversationId]))
            .get();

    final totals = <String, double>{};
    for (final row in rows) {
      final conversationId = row.read(conversationAiCostEntries.conversationId);
      final total = row.read(totalExpression);
      if (conversationId != null && total != null) {
        totals[conversationId] = total;
      }
    }
    return totals;
  }

  // ---------------------------------------------------------------------------
  // Topics
  // ---------------------------------------------------------------------------

  /// Insert a topic.
  Future<void> insertTopic(TopicsCompanion entry) {
    return into(topics).insert(entry);
  }

  /// All topics for a conversation, ordered.
  Future<List<Topic>> getTopicsForConversation(String conversationId) {
    return (select(topics)
          ..where((t) => t.conversationId.equals(conversationId))
          ..orderBy([(t) => OrderingTerm.asc(t.sortOrder)]))
        .get();
  }

  // ---------------------------------------------------------------------------
  // FTS5 search
  // ---------------------------------------------------------------------------

  /// Full-text search across conversation segment text.
  Future<List<ConversationSegment>> searchSegments(String query) async {
    final results = await customSelect(
      'SELECT cs.* FROM conversation_segments cs '
      'INNER JOIN conversation_segments_fts fts ON cs.rowid = fts.rowid '
      'WHERE conversation_segments_fts MATCH ?1 '
      'ORDER BY rank',
      variables: [Variable.withString(query)],
      readsFrom: {conversationSegments},
    ).get();

    return results.map((row) => conversationSegments.map(row.data)).toList();
  }
}
