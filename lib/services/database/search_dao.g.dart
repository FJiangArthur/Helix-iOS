// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'search_dao.dart';

// ignore_for_file: type=lint
mixin _$SearchDaoMixin on DatabaseAccessor<HelixDatabase> {
  $ConversationsTable get conversations => attachedDatabase.conversations;
  $ConversationSegmentsTable get conversationSegments =>
      attachedDatabase.conversationSegments;
  $FactsTable get facts => attachedDatabase.facts;
  SearchDaoManager get managers => SearchDaoManager(this);
}

class SearchDaoManager {
  final _$SearchDaoMixin _db;
  SearchDaoManager(this._db);
  $$ConversationsTableTableManager get conversations =>
      $$ConversationsTableTableManager(_db.attachedDatabase, _db.conversations);
  $$ConversationSegmentsTableTableManager get conversationSegments =>
      $$ConversationSegmentsTableTableManager(
        _db.attachedDatabase,
        _db.conversationSegments,
      );
  $$FactsTableTableManager get facts =>
      $$FactsTableTableManager(_db.attachedDatabase, _db.facts);
}
