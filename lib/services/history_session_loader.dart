import '../models/assistant_session_meta.dart';
import 'conversation_engine.dart';
import 'database/helix_database.dart';
import 'settings_manager.dart';
import '../utils/i18n.dart';

String historyModeLabel(String? mode) {
  if (mode == null || mode.isEmpty) {
    return 'General';
  }
  return mode[0].toUpperCase() + mode.substring(1).toLowerCase();
}

class HistorySessionLoader {
  const HistorySessionLoader._();

  static Future<List<AssistantSessionMeta>> loadPersistedSessions({
    required List<String> favoriteIds,
    HelixDatabase? database,
    SettingsManager? settingsManager,
  }) async {
    final db = database ?? HelixDatabase.instance;
    final settings = settingsManager ?? SettingsManager.instance;
    final profiles = settings.assistantProfiles;
    final conversations = await db.conversationDao.getAllConversations(
      limit: 200,
    );
    final sessions = <AssistantSessionMeta>[];

    for (final conversation in conversations) {
      final segments = await db.conversationDao.getSegmentsForConversation(
        conversation.id,
      );
      if (segments.isEmpty &&
          (conversation.title?.trim().isEmpty ?? true) &&
          (conversation.summary?.trim().isEmpty ?? true)) {
        continue;
      }

      final turns = segments
          .map(
            (segment) => ConversationTurn(
              role: segment.speakerLabel?.toLowerCase() == 'assistant'
                  ? 'assistant'
                  : 'user',
              content: segment.text_,
              timestamp: DateTime.fromMillisecondsSinceEpoch(segment.startedAt),
              mode: conversation.mode,
              assistantProfileId: settings.assistantProfileId,
            ),
          )
          .toList();

      final baseMeta = turns.isEmpty
          ? null
          : AssistantSessionMeta.fromTurns(
              turns,
              profiles: profiles,
              isFavorite: favoriteIds.contains(conversation.id),
            );
      final startedAt = DateTime.fromMillisecondsSinceEpoch(
        conversation.startedAt,
      );
      final endedAtMs = conversation.endedAt ?? conversation.startedAt;

      sessions.add(
        AssistantSessionMeta(
          id: conversation.id,
          turns: turns,
          modeLabel: historyModeLabel(conversation.mode),
          profileId: baseMeta?.profileId ?? 'general',
          profileLabel: baseMeta?.profileLabel ?? 'Session',
          startedAt: startedAt,
          duration: Duration(
            milliseconds: (endedAtMs - conversation.startedAt).clamp(
              0,
              86400000,
            ),
          ),
          summaryTitle: conversation.title?.trim().isNotEmpty == true
              ? conversation.title!.trim()
              : (baseMeta?.summaryTitle ?? tr('Recorded Session', '录制会话')),
          summaryBody: conversation.summary?.trim().isNotEmpty == true
              ? conversation.summary!.trim()
              : (baseMeta?.summaryBody ??
                    turns
                        .take(3)
                        .map((turn) => turn.content)
                        .join('  ')
                        .trim()),
          promptPreview: baseMeta?.promptPreview ?? '',
          answerPreview: baseMeta?.answerPreview ?? '',
          assistantCount: turns
              .where((turn) => turn.role == 'assistant')
              .length,
          actionItems: baseMeta?.actionItems ?? const [],
          verificationCandidates: baseMeta?.verificationCandidates ?? const [],
          reviewBrief: baseMeta?.reviewBrief ?? '',
          reviewSignalCount: baseMeta?.reviewSignalCount ?? 0,
          searchableText: [
            conversation.title ?? '',
            conversation.summary ?? '',
            ...turns.map((turn) => turn.content),
          ].join(' ').toLowerCase(),
          fullTranscript: turns.isEmpty
              ? (conversation.summary ?? '')
              : turns
                    .map(
                      (turn) =>
                          '${turn.role == 'assistant' ? 'Even AI' : 'Conversation'}: ${turn.content}',
                    )
                    .join('\n\n'),
          isFavorite: favoriteIds.contains(conversation.id),
        ),
      );
    }

    return sessions;
  }
}
