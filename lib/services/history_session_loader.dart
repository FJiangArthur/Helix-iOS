import '../models/assistant_session_meta.dart';
import 'database/helix_database.dart';
import 'settings_manager.dart';
import '../utils/conversation_mode_labels.dart';
import '../utils/i18n.dart';

String historyModeLabel(String? mode) {
  return storedConversationModeLabel(mode);
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

      final startedAt = DateTime.fromMillisecondsSinceEpoch(
        conversation.startedAt,
      );
      final endedAtMs = conversation.endedAt ?? conversation.startedAt;
      final timelineEntries = segments
          .map(
            (segment) => SessionTimelineEntry(
              speakerLabel: (segment.speakerLabel ?? '').trim(),
              text: segment.text_,
              timestamp: DateTime.fromMillisecondsSinceEpoch(segment.startedAt),
            ),
          )
          .toList(growable: false);

      if (timelineEntries.isNotEmpty) {
        sessions.add(
          AssistantSessionMeta.fromTimelineEntries(
            timelineEntries,
            id: conversation.id,
            mode: conversation.mode,
            profileId: settings.assistantProfileId,
            title: conversation.title,
            summary: conversation.summary,
            profiles: profiles,
            isFavorite: favoriteIds.contains(conversation.id),
            costSmartUsdMicros: conversation.costSmartUsdMicros,
            costLightUsdMicros: conversation.costLightUsdMicros,
            costTranscriptionUsdMicros: conversation.costTranscriptionUsdMicros,
            costTotalUsdMicros: conversation.costTotalUsdMicros,
          ),
        );
        continue;
      }

      sessions.add(
        AssistantSessionMeta(
          id: conversation.id,
          costSmartUsdMicros: conversation.costSmartUsdMicros,
          costLightUsdMicros: conversation.costLightUsdMicros,
          costTranscriptionUsdMicros: conversation.costTranscriptionUsdMicros,
          costTotalUsdMicros: conversation.costTotalUsdMicros,
          turns: const [],
          timelineEntries: const [],
          modeLabel: historyModeLabel(conversation.mode),
          profileId: 'general',
          profileLabel: 'Session',
          startedAt: startedAt,
          duration: Duration(
            milliseconds: (endedAtMs - conversation.startedAt).clamp(
              0,
              86400000,
            ),
          ),
          summaryTitle: conversation.title?.trim().isNotEmpty == true
              ? conversation.title!.trim()
              : tr('Recorded Session', '录制会话'),
          summaryBody: conversation.summary?.trim().isNotEmpty == true
              ? conversation.summary!.trim()
              : '',
          promptPreview: '',
          answerPreview: '',
          assistantCount: 0,
          actionItems: const [],
          verificationCandidates: const [],
          reviewBrief: '',
          reviewSignalCount: 0,
          searchableText: [
            conversation.title ?? '',
            conversation.summary ?? '',
          ].join(' ').toLowerCase(),
          fullTranscript: conversation.summary ?? '',
          isFavorite: favoriteIds.contains(conversation.id),
        ),
      );
    }

    return sessions;
  }
}
