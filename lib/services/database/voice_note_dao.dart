import 'package:drift/drift.dart';

import 'helix_database.dart';

part 'voice_note_dao.g.dart';

@DriftAccessor(tables: [VoiceNotes])
class VoiceNoteDao extends DatabaseAccessor<HelixDatabase>
    with _$VoiceNoteDaoMixin {
  VoiceNoteDao(super.db);

  /// Insert a new voice note.
  Future<void> insertVoiceNote(VoiceNotesCompanion entry) {
    return into(voiceNotes).insert(entry);
  }

  /// Update an existing voice note.
  Future<bool> updateVoiceNote(VoiceNotesCompanion entry) {
    return (update(voiceNotes)
          ..where((v) => v.id.equals(entry.id.value)))
        .write(entry)
        .then((rows) => rows > 0);
  }

  /// Paginated list of voice notes (newest first).
  Future<List<VoiceNote>> getAllVoiceNotes({
    int limit = 50,
    int offset = 0,
  }) {
    return (select(voiceNotes)
          ..orderBy([(v) => OrderingTerm.desc(v.createdAt)])
          ..limit(limit, offset: offset))
        .get();
  }

  /// Stream of all voice notes (newest first).
  Stream<List<VoiceNote>> watchVoiceNotes() {
    return (select(voiceNotes)
          ..orderBy([(v) => OrderingTerm.desc(v.createdAt)]))
        .watch();
  }
}
