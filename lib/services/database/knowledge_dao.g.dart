// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'knowledge_dao.dart';

// ignore_for_file: type=lint
mixin _$KnowledgeDaoMixin on DatabaseAccessor<HelixDatabase> {
  $KnowledgeEntitiesTable get knowledgeEntities =>
      attachedDatabase.knowledgeEntities;
  $KnowledgeRelationshipsTable get knowledgeRelationships =>
      attachedDatabase.knowledgeRelationships;
  $UserProfilesTable get userProfiles => attachedDatabase.userProfiles;
  KnowledgeDaoManager get managers => KnowledgeDaoManager(this);
}

class KnowledgeDaoManager {
  final _$KnowledgeDaoMixin _db;
  KnowledgeDaoManager(this._db);
  $$KnowledgeEntitiesTableTableManager get knowledgeEntities =>
      $$KnowledgeEntitiesTableTableManager(
        _db.attachedDatabase,
        _db.knowledgeEntities,
      );
  $$KnowledgeRelationshipsTableTableManager get knowledgeRelationships =>
      $$KnowledgeRelationshipsTableTableManager(
        _db.attachedDatabase,
        _db.knowledgeRelationships,
      );
  $$UserProfilesTableTableManager get userProfiles =>
      $$UserProfilesTableTableManager(_db.attachedDatabase, _db.userProfiles);
}
