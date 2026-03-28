// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'daily_memory_dao.dart';

// ignore_for_file: type=lint
mixin _$DailyMemoryDaoMixin on DatabaseAccessor<HelixDatabase> {
  $DailyMemoriesTable get dailyMemories => attachedDatabase.dailyMemories;
  DailyMemoryDaoManager get managers => DailyMemoryDaoManager(this);
}

class DailyMemoryDaoManager {
  final _$DailyMemoryDaoMixin _db;
  DailyMemoryDaoManager(this._db);
  $$DailyMemoriesTableTableManager get dailyMemories =>
      $$DailyMemoriesTableTableManager(_db.attachedDatabase, _db.dailyMemories);
}
