// ABOUTME: Singleton facade over ProjectDao for service-layer callers.
// ABOUTME: Owns soft-delete / undo / purge semantics for projects.

import '../database/helix_database.dart';

class ProjectsService {
  ProjectsService._(this._db);

  static ProjectsService? _instance;
  static ProjectsService get instance =>
      _instance ??= ProjectsService._(HelixDatabase.instance);

  /// Tests only.
  factory ProjectsService.forTesting(HelixDatabase db) {
    final svc = ProjectsService._(db);
    _instance = svc;
    return svc;
  }

  static void resetForTesting() {
    _instance = null;
  }

  final HelixDatabase _db;

  Stream<List<Project>> watchProjects() =>
      _db.projectDao.watchActiveProjects();

  Stream<List<Project>> watchRecentlyDeleted() =>
      _db.projectDao.watchRecentlyDeleted();

  Future<Project?> getById(String id) => _db.projectDao.getProjectById(id);

  Future<Project> createProject({required String name, String? description}) =>
      _db.projectDao.createProject(name: name, description: description);

  Future<void> updateProject({
    required String id,
    String? name,
    String? description,
    int? chunkSizeTokens,
    int? chunkOverlapTokens,
    int? retrievalTopK,
    double? retrievalMinSimilarity,
  }) =>
      _db.projectDao.updateProject(
        id: id,
        name: name,
        description: description,
        chunkSizeTokens: chunkSizeTokens,
        chunkOverlapTokens: chunkOverlapTokens,
        retrievalTopK: retrievalTopK,
        retrievalMinSimilarity: retrievalMinSimilarity,
      );

  Future<void> softDelete(String id) => _db.projectDao.softDeleteProject(id);

  Future<void> undoDelete(String id) => _db.projectDao.undoDelete(id);

  /// Should be called once on app launch.
  Future<int> purgeExpiredSoftDeletes() =>
      _db.projectDao.purgeExpiredSoftDeletes();
}
