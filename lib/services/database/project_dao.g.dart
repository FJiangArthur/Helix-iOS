// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'project_dao.dart';

// ignore_for_file: type=lint
mixin _$ProjectDaoMixin on DatabaseAccessor<HelixDatabase> {
  $ProjectsTable get projects => attachedDatabase.projects;
  $ProjectDocumentsTable get projectDocuments =>
      attachedDatabase.projectDocuments;
  $ProjectDocumentChunksTable get projectDocumentChunks =>
      attachedDatabase.projectDocumentChunks;
  $ProjectDocumentChunkVectorsTable get projectDocumentChunkVectors =>
      attachedDatabase.projectDocumentChunkVectors;
  ProjectDaoManager get managers => ProjectDaoManager(this);
}

class ProjectDaoManager {
  final _$ProjectDaoMixin _db;
  ProjectDaoManager(this._db);
  $$ProjectsTableTableManager get projects =>
      $$ProjectsTableTableManager(_db.attachedDatabase, _db.projects);
  $$ProjectDocumentsTableTableManager get projectDocuments =>
      $$ProjectDocumentsTableTableManager(
        _db.attachedDatabase,
        _db.projectDocuments,
      );
  $$ProjectDocumentChunksTableTableManager get projectDocumentChunks =>
      $$ProjectDocumentChunksTableTableManager(
        _db.attachedDatabase,
        _db.projectDocumentChunks,
      );
  $$ProjectDocumentChunkVectorsTableTableManager
  get projectDocumentChunkVectors =>
      $$ProjectDocumentChunkVectorsTableTableManager(
        _db.attachedDatabase,
        _db.projectDocumentChunkVectors,
      );
}
