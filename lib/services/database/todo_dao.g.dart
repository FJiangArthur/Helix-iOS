// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'todo_dao.dart';

// ignore_for_file: type=lint
mixin _$TodoDaoMixin on DatabaseAccessor<HelixDatabase> {
  $TodosTable get todos => attachedDatabase.todos;
  TodoDaoManager get managers => TodoDaoManager(this);
}

class TodoDaoManager {
  final _$TodoDaoMixin _db;
  TodoDaoManager(this._db);
  $$TodosTableTableManager get todos =>
      $$TodosTableTableManager(_db.attachedDatabase, _db.todos);
}
