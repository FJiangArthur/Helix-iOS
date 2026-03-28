import 'package:drift/drift.dart';

import 'helix_database.dart';

part 'facts_dao.g.dart';

@DriftAccessor(tables: [Facts])
class FactsDao extends DatabaseAccessor<HelixDatabase>
    with _$FactsDaoMixin {
  FactsDao(super.db);

  /// Insert a new fact.
  Future<void> insertFact(FactsCompanion entry) {
    return into(facts).insert(entry);
  }

  /// Update the status of a fact (pending → confirmed / rejected).
  Future<void> updateFactStatus(String id, String status) {
    final now = DateTime.now().millisecondsSinceEpoch;
    return (update(facts)..where((f) => f.id.equals(id))).write(
      FactsCompanion(
        status: Value(status),
        confirmedAt:
            status == 'confirmed' ? Value(now) : const Value.absent(),
      ),
    );
  }

  /// Pending facts, newest first.
  Future<List<Fact>> getPendingFacts({int limit = 50}) {
    return (select(facts)
          ..where((f) => f.status.equals('pending'))
          ..orderBy([(f) => OrderingTerm.desc(f.createdAt)])
          ..limit(limit))
        .get();
  }

  /// Stream of pending facts.
  Stream<List<Fact>> watchPendingFacts() {
    return (select(facts)
          ..where((f) => f.status.equals('pending'))
          ..orderBy([(f) => OrderingTerm.desc(f.createdAt)]))
        .watch();
  }

  /// Confirmed facts with optional category filter and pagination.
  Future<List<Fact>> getConfirmedFacts({
    String? category,
    int limit = 50,
    int offset = 0,
  }) {
    final query = select(facts)
      ..where((f) => f.status.equals('confirmed'))
      ..orderBy([(f) => OrderingTerm.desc(f.createdAt)])
      ..limit(limit, offset: offset);
    if (category != null) {
      query.where((f) => f.category.equals(category));
    }
    return query.get();
  }

  /// Stream of confirmed facts.
  Stream<List<Fact>> watchConfirmedFacts() {
    return (select(facts)
          ..where((f) => f.status.equals('confirmed'))
          ..orderBy([(f) => OrderingTerm.desc(f.createdAt)]))
        .watch();
  }

  /// Find facts by dedupe key (for duplicate detection).
  Future<List<Fact>> getFactsByDedupeKey(String key) {
    return (select(facts)..where((f) => f.dedupeKey.equals(key))).get();
  }

  /// Full-text search across fact content and category.
  Future<List<Fact>> searchFacts(String query) async {
    final results = await customSelect(
      'SELECT f.* FROM facts f '
      'INNER JOIN facts_fts fts ON f.rowid = fts.rowid '
      'WHERE facts_fts MATCH ?1 '
      'ORDER BY rank',
      variables: [Variable.withString(query)],
      readsFrom: {facts},
    ).get();

    return results.map((row) => facts.map(row.data)).toList();
  }

  /// Count of confirmed facts.
  Future<int> getConfirmedFactCount() async {
    final count = countAll();
    final query = selectOnly(facts)
      ..where(facts.status.equals('confirmed'))
      ..addColumns([count]);
    final result = await query.getSingle();
    return result.read(count) ?? 0;
  }
}
