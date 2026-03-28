// ABOUTME: Singleton service for capturing, transcribing, and summarizing voice notes.
// ABOUTME: Triggered by long-press gestures on glasses. Saves to drift database.

import 'dart:async';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../utils/app_logger.dart';
import 'database/helix_database.dart';
import 'llm/llm_service.dart';
import 'llm/llm_provider.dart';
import 'settings_manager.dart';

/// Service for capturing, transcribing, and summarizing voice notes.
///
/// Voice notes are triggered by long-press gestures on the glasses.
/// The flow: start capture -> accumulate transcript -> stop -> summarize -> save to DB.
class VoiceNoteService {
  static VoiceNoteService? _instance;
  static VoiceNoteService get instance => _instance ??= VoiceNoteService._();
  VoiceNoteService._();

  static const _uuid = Uuid();

  bool _isRecording = false;
  bool get isRecording => _isRecording;

  String? _currentNoteId;
  DateTime? _startTime;
  final StringBuffer _transcriptBuffer = StringBuffer();

  final _recordingStateController = StreamController<bool>.broadcast();
  Stream<bool> get recordingStateStream => _recordingStateController.stream;

  final _voiceNotesController = StreamController<void>.broadcast();

  /// Fires when a new voice note is saved (for UI refresh).
  Stream<void> get onVoiceNoteSaved => _voiceNotesController.stream;

  /// Start recording a voice note.
  Future<void> startRecording() async {
    if (_isRecording) return;

    _isRecording = true;
    _currentNoteId = _uuid.v4();
    _startTime = DateTime.now();
    _transcriptBuffer.clear();
    _recordingStateController.add(true);

    appLogger.i('[VoiceNote] Started recording note $_currentNoteId');

    // The actual audio capture is handled by the native SpeechStreamRecognizer
    // via the existing platform channel. We receive transcription callbacks
    // through the ConversationListeningSession or directly.
  }

  /// Called when transcription text arrives during voice note recording.
  void onTranscription(String text) {
    if (!_isRecording) return;
    _transcriptBuffer.clear();
    _transcriptBuffer.write(text);
  }

  /// Stop recording and save the voice note.
  Future<void> stopRecording() async {
    if (!_isRecording) return;

    _isRecording = false;
    _recordingStateController.add(false);

    final noteId = _currentNoteId;
    final startTime = _startTime;
    final transcript = _transcriptBuffer.toString().trim();

    if (noteId == null || startTime == null) return;

    final durationMs = DateTime.now().difference(startTime).inMilliseconds;

    appLogger.i(
      '[VoiceNote] Stopped recording $noteId '
      '(${durationMs}ms, ${transcript.length} chars)',
    );

    if (transcript.isEmpty) {
      appLogger.w('[VoiceNote] Empty transcript, discarding note');
      return;
    }

    // Save to database.
    final db = HelixDatabase.instance;
    await db.voiceNoteDao.insertVoiceNote(
      VoiceNotesCompanion.insert(
        id: noteId,
        createdAt: startTime.millisecondsSinceEpoch,
        durationMs: Value(durationMs),
        transcript: Value(transcript),
      ),
    );

    _voiceNotesController.add(null);
    appLogger.i('[VoiceNote] Saved note $noteId');

    // Summarize asynchronously (fire-and-forget).
    _summarizeNote(noteId, transcript);

    _currentNoteId = null;
    _startTime = null;
    _transcriptBuffer.clear();
  }

  /// Summarize a voice note using LLM.
  Future<void> _summarizeNote(String noteId, String transcript) async {
    try {
      final llm = LlmService.instance;
      final isChinese = SettingsManager.instance.language == 'zh';

      final response = await llm.getResponse(
        systemPrompt: isChinese
            ? '你是一个简洁的笔记助手。用一句话总结以下语音笔记。'
            : 'You are a concise note assistant. '
                'Summarize this voice note in one sentence.',
        messages: [ChatMessage(role: 'user', content: transcript)],
      );

      // Update the note with the summary.
      final db = HelixDatabase.instance;
      await db.voiceNoteDao.updateVoiceNote(
        VoiceNotesCompanion(
          id: Value(noteId),
          summary: Value(response.trim()),
        ),
      );

      _voiceNotesController.add(null);
      appLogger.i('[VoiceNote] Summary generated for $noteId');
    } catch (e) {
      appLogger.e('[VoiceNote] Failed to summarize note $noteId', error: e);
    }
  }

  /// Get all voice notes from the database.
  Future<List<VoiceNote>> getAllNotes({int limit = 50, int offset = 0}) async {
    return HelixDatabase.instance.voiceNoteDao.getAllVoiceNotes(
      limit: limit,
      offset: offset,
    );
  }

  /// Watch voice notes for reactive UI updates.
  Stream<List<VoiceNote>> watchNotes() {
    return HelixDatabase.instance.voiceNoteDao.watchVoiceNotes();
  }

  void dispose() {
    _recordingStateController.close();
    _voiceNotesController.close();
  }
}
