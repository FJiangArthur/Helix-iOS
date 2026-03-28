// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'conversation_dao.dart';

// ignore_for_file: type=lint
mixin _$ConversationDaoMixin on DatabaseAccessor<HelixDatabase> {
  $ConversationsTable get conversations => attachedDatabase.conversations;
  $ConversationSegmentsTable get conversationSegments =>
      attachedDatabase.conversationSegments;
  $TopicsTable get topics => attachedDatabase.topics;
  ConversationDaoManager get managers => ConversationDaoManager(this);
}

class ConversationDaoManager {
  final _$ConversationDaoMixin _db;
  ConversationDaoManager(this._db);
  $$ConversationsTableTableManager get conversations =>
      $$ConversationsTableTableManager(_db.attachedDatabase, _db.conversations);
  $$ConversationSegmentsTableTableManager get conversationSegments =>
      $$ConversationSegmentsTableTableManager(
        _db.attachedDatabase,
        _db.conversationSegments,
      );
  $$TopicsTableTableManager get topics =>
      $$TopicsTableTableManager(_db.attachedDatabase, _db.topics);
}
