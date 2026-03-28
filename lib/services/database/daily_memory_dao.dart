import 'package:drift/drift.dart';

import 'helix_database.dart';

part 'daily_memory_dao.g.dart';

@DriftAccessor(tables: [DailyMemories])
class DailyMemoryDao extends DatabaseAccessor<HelixDatabase>
    with _$DailyMemoryDaoMixin {
  DailyMemoryDao(super.db);

  /// Insert a new daily memory.
  Future<void> insertDailyMemory(DailyMemoriesCompanion entry) {
    return into(dailyMemories).insert(entry);
  }

  /// Get a daily memory by ISO date string (e.g. '2026-03-26').
  Future<DailyMemory?> getDailyMemory(String date) {
    return (select(dailyMemories)..where((d) => d.date.equals(date)))
        .getSingleOrNull();
  }

  /// Stream of all daily memories (newest first).
  Stream<List<DailyMemory>> watchDailyMemories() {
    return (select(dailyMemories)
          ..orderBy([(d) => OrderingTerm.desc(d.generatedAt)]))
        .watch();
  }

  /// Delete a daily memory by date string.
  Future<int> deleteDailyMemory(String date) {
    return (delete(dailyMemories)..where((d) => d.date.equals(date))).go();
  }

  /// Recent memories, limited.
  Future<List<DailyMemory>> getRecentMemories({int limit = 7}) {
    return (select(dailyMemories)
          ..orderBy([(d) => OrderingTerm.desc(d.generatedAt)])
          ..limit(limit))
        .get();
  }
}
