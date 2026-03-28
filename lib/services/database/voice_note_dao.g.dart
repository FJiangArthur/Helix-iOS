// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'voice_note_dao.dart';

// ignore_for_file: type=lint
mixin _$VoiceNoteDaoMixin on DatabaseAccessor<HelixDatabase> {
  $VoiceNotesTable get voiceNotes => attachedDatabase.voiceNotes;
  VoiceNoteDaoManager get managers => VoiceNoteDaoManager(this);
}

class VoiceNoteDaoManager {
  final _$VoiceNoteDaoMixin _db;
  VoiceNoteDaoManager(this._db);
  $$VoiceNotesTableTableManager get voiceNotes =>
      $$VoiceNotesTableTableManager(_db.attachedDatabase, _db.voiceNotes);
}
