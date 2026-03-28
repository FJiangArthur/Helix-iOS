// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'facts_dao.dart';

// ignore_for_file: type=lint
mixin _$FactsDaoMixin on DatabaseAccessor<HelixDatabase> {
  $FactsTable get facts => attachedDatabase.facts;
  FactsDaoManager get managers => FactsDaoManager(this);
}

class FactsDaoManager {
  final _$FactsDaoMixin _db;
  FactsDaoManager(this._db);
  $$FactsTableTableManager get facts =>
      $$FactsTableTableManager(_db.attachedDatabase, _db.facts);
}
