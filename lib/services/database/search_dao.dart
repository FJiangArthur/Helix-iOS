import 'package:drift/drift.dart';

import 'helix_database.dart';

part 'search_dao.g.dart';

/// A unified search result from any FTS-indexed source.
class SearchResult {
  final String type; // 'segment' or 'fact'
  final String id;
  final String text;
  final String? conversationId;
  final double rank;

  const SearchResult({
    required this.type,
    required this.id,
    required this.text,
    this.conversationId,
    this.rank = 0,
  });
}

@DriftAccessor(tables: [ConversationSegments, Facts])
class SearchDao extends DatabaseAccessor<HelixDatabase>
    with _$SearchDaoMixin {
  SearchDao(super.db);

  /// Search across both conversation segments and facts using FTS5.
  /// Returns a merged, rank-ordered list of results.
  Future<List<SearchResult>> searchAll(String query) async {
    final segmentResults = await customSelect(
      'SELECT cs.id, cs.text, cs.conversation_id, rank '
      'FROM conversation_segments_fts fts '
      'INNER JOIN conversation_segments cs ON cs.rowid = fts.rowid '
      'WHERE conversation_segments_fts MATCH ?1',
      variables: [Variable.withString(query)],
      readsFrom: {conversationSegments},
    ).get();

    final factResults = await customSelect(
      'SELECT f.id, f.content, f.conversation_id, rank '
      'FROM facts_fts fts '
      'INNER JOIN facts f ON f.rowid = fts.rowid '
      'WHERE facts_fts MATCH ?1',
      variables: [Variable.withString(query)],
      readsFrom: {facts},
    ).get();

    final results = <SearchResult>[];

    for (final row in segmentResults) {
      results.add(SearchResult(
        type: 'segment',
        id: row.read<String>('id'),
        text: row.read<String>('text'),
        conversationId: row.readNullable<String>('conversation_id'),
        rank: row.read<double>('rank'),
      ));
    }

    for (final row in factResults) {
      results.add(SearchResult(
        type: 'fact',
        id: row.read<String>('id'),
        text: row.read<String>('content'),
        conversationId: row.readNullable<String>('conversation_id'),
        rank: row.read<double>('rank'),
      ));
    }

    // Lower rank = better match in FTS5
    results.sort((a, b) => a.rank.compareTo(b.rank));
    return results;
  }
}
