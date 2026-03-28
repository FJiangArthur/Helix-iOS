import '../../utils/app_logger.dart';
import '../database/helix_database.dart';

/// Central business-logic layer for the Facts system.
///
/// Delegates storage operations to [FactsDao] and provides a clean API for the
/// UI to query, confirm, reject, and search user facts.
class FactService {
  static FactService? _instance;
  static FactService get instance => _instance ??= FactService._();

  FactService._();

  // ---------------------------------------------------------------------------
  // Pending facts
  // ---------------------------------------------------------------------------

  /// Get pending facts for the swipe-to-confirm UI.
  Future<List<Fact>> getPendingFacts({int limit = 20}) async {
    return HelixDatabase.instance.factsDao.getPendingFacts(limit: limit);
  }

  /// Watch pending facts reactively.
  Stream<List<Fact>> watchPendingFacts() {
    return HelixDatabase.instance.factsDao.watchPendingFacts();
  }

  // ---------------------------------------------------------------------------
  // Confirm / Reject
  // ---------------------------------------------------------------------------

  /// Confirm a fact — moves it into the user's knowledge graph.
  Future<void> confirmFact(String factId) async {
    try {
      await HelixDatabase.instance.factsDao
          .updateFactStatus(factId, 'confirmed');
      appLogger.i('[FactService] Confirmed fact $factId');
    } catch (e, st) {
      appLogger.e('[FactService] Failed to confirm fact $factId',
          error: e, stackTrace: st);
      rethrow;
    }
  }

  /// Reject a fact — marks it as rejected so it won't be re-extracted.
  Future<void> rejectFact(String factId) async {
    try {
      await HelixDatabase.instance.factsDao
          .updateFactStatus(factId, 'rejected');
      appLogger.i('[FactService] Rejected fact $factId');
    } catch (e, st) {
      appLogger.e('[FactService] Failed to reject fact $factId',
          error: e, stackTrace: st);
      rethrow;
    }
  }

  // ---------------------------------------------------------------------------
  // Confirmed facts
  // ---------------------------------------------------------------------------

  /// Get all confirmed facts, optionally filtered by [category].
  Future<List<Fact>> getConfirmedFacts({
    String? category,
    int limit = 100,
  }) async {
    return HelixDatabase.instance.factsDao
        .getConfirmedFacts(category: category, limit: limit);
  }

  /// Watch confirmed facts reactively.
  Stream<List<Fact>> watchConfirmedFacts() {
    return HelixDatabase.instance.factsDao.watchConfirmedFacts();
  }

  /// Get total confirmed fact count.
  Future<int> getConfirmedCount() async {
    return HelixDatabase.instance.factsDao.getConfirmedFactCount();
  }

  // ---------------------------------------------------------------------------
  // Search
  // ---------------------------------------------------------------------------

  /// Search facts by content using full-text search.
  Future<List<Fact>> searchFacts(String query) async {
    if (query.trim().isEmpty) return [];
    try {
      return await HelixDatabase.instance.factsDao.searchFacts(query);
    } catch (e) {
      appLogger.w('[FactService] Search failed for "$query": $e');
      return [];
    }
  }
}
