import '../services/conversation_engine.dart';
import '../utils/conversation_mode_labels.dart';
import 'assistant_profile.dart';

class AssistantSessionMeta {
  AssistantSessionMeta({
    required this.id,
    required this.turns,
    required this.timelineEntries,
    required this.modeLabel,
    required this.profileId,
    required this.profileLabel,
    required this.startedAt,
    required this.duration,
    required this.summaryTitle,
    required this.summaryBody,
    required this.promptPreview,
    required this.answerPreview,
    required this.assistantCount,
    required this.actionItems,
    required this.verificationCandidates,
    required this.reviewBrief,
    required this.reviewSignalCount,
    required this.searchableText,
    required this.fullTranscript,
    this.isFavorite = false,
    this.costSmartUsdMicros,
    this.costLightUsdMicros,
    this.costTranscriptionUsdMicros,
    this.costTotalUsdMicros,
  });

  factory AssistantSessionMeta.fromTurns(
    List<ConversationTurn> turns, {
    List<AssistantProfile> profiles = const [],
    bool isFavorite = false,
  }) {
    final first = turns.first;
    final last = turns.last;
    final firstUser = turns.cast<ConversationTurn?>().firstWhere(
      (turn) => turn?.role == 'user',
      orElse: () => first,
    )!;
    final firstAssistant = turns.cast<ConversationTurn?>().firstWhere(
      (turn) => turn?.role == 'assistant',
      orElse: () => null,
    );
    final profileId = turns
        .map((turn) => turn.assistantProfileId)
        .whereType<String>()
        .firstWhere((value) => value.isNotEmpty, orElse: () => 'general');
    final profile = AssistantProfile.normalize(profiles).firstWhere(
      (candidate) => candidate.id == profileId,
      orElse: () => AssistantProfile.fallback(profileId),
    );
    final actionItems = _extractActionItems(turns);
    final verificationCandidates = _extractVerificationCandidates(turns);
    final summaryTitle = firstAssistant != null
        ? _compactLine(firstAssistant.content, maxLength: 72)
        : _compactLine(firstUser.content, maxLength: 72);
    final summaryBody = _summaryBody(turns);
    final timelineEntries = turns
        .map(SessionTimelineEntry.fromTurn)
        .toList(growable: false);

    return AssistantSessionMeta(
      id: '${first.timestamp.millisecondsSinceEpoch}-${turns.length}',
      turns: turns,
      timelineEntries: timelineEntries,
      modeLabel: _modeLabel(first.mode),
      profileId: profile.id,
      profileLabel: profile.name,
      startedAt: first.timestamp,
      duration: last.timestamp.difference(first.timestamp),
      summaryTitle: summaryTitle,
      summaryBody: summaryBody,
      promptPreview: _compactLine(firstUser.content),
      answerPreview: _compactLine(
        firstAssistant?.content ?? turns.last.content,
      ),
      assistantCount: turns.where((turn) => turn.role == 'assistant').length,
      actionItems: actionItems,
      verificationCandidates: verificationCandidates,
      reviewBrief: _buildReviewBrief(
        summaryTitle: summaryTitle,
        summaryBody: summaryBody,
        actionItems: actionItems,
        verificationCandidates: verificationCandidates,
      ),
      reviewSignalCount: actionItems.length + verificationCandidates.length,
      searchableText: turns.map((turn) => turn.content.toLowerCase()).join(' '),
      fullTranscript: turns
          .map(
            (turn) =>
                '${turn.role == 'user' ? 'You' : 'Even AI'}: ${turn.content}',
          )
          .join('\n\n'),
      isFavorite: isFavorite,
    );
  }

  factory AssistantSessionMeta.fromTimelineEntries(
    List<SessionTimelineEntry> timelineEntries, {
    required String id,
    String? mode,
    String? profileId,
    String? title,
    String? summary,
    List<AssistantProfile> profiles = const [],
    bool isFavorite = false,
    int? costSmartUsdMicros,
    int? costLightUsdMicros,
    int? costTranscriptionUsdMicros,
    int? costTotalUsdMicros,
  }) {
    final first = timelineEntries.first;
    final last = timelineEntries.last;
    final transcriptEntries = timelineEntries
        .where((entry) => !entry.isAssistant)
        .toList(growable: false);
    final assistantEntries = timelineEntries
        .where((entry) => entry.isAssistant)
        .toList(growable: false);
    final primaryTranscript = transcriptEntries.isNotEmpty
        ? transcriptEntries.first
        : first;
    final firstAssistant = assistantEntries.isNotEmpty
        ? assistantEntries.first
        : null;
    final resolvedProfileId = (profileId ?? '').trim().isNotEmpty
        ? profileId!.trim()
        : 'general';
    final profile = AssistantProfile.normalize(profiles).firstWhere(
      (candidate) => candidate.id == resolvedProfileId,
      orElse: () => AssistantProfile.fallback(resolvedProfileId),
    );
    final turns = timelineEntries
        .map(
          (entry) => ConversationTurn(
            role: entry.isAssistant ? 'assistant' : 'user',
            content: entry.text,
            timestamp: entry.timestamp,
            mode: mode,
            assistantProfileId: resolvedProfileId,
          ),
        )
        .toList(growable: false);
    final actionItems = _extractActionItems(turns);
    final verificationCandidates = _extractVerificationCandidates(turns);
    final normalizedTitle = title?.trim() ?? '';
    final normalizedSummary = summary?.trim() ?? '';
    final summaryTitle = normalizedTitle.isNotEmpty
        ? normalizedTitle
        : _compactLine(primaryTranscript.text, maxLength: 72);
    final summaryBody = normalizedSummary.isNotEmpty
        ? normalizedSummary
        : _timelineSummaryBody(timelineEntries);

    return AssistantSessionMeta(
      id: id,
      turns: turns,
      timelineEntries: timelineEntries,
      modeLabel: _modeLabel(mode),
      profileId: profile.id,
      profileLabel: profile.name,
      startedAt: first.timestamp,
      duration: last.timestamp.difference(first.timestamp),
      summaryTitle: summaryTitle,
      summaryBody: summaryBody,
      promptPreview: _compactLine(primaryTranscript.text),
      answerPreview: _compactLine(firstAssistant?.text ?? ''),
      assistantCount: assistantEntries.length,
      actionItems: actionItems,
      verificationCandidates: verificationCandidates,
      reviewBrief: _buildReviewBrief(
        summaryTitle: summaryTitle,
        summaryBody: summaryBody,
        actionItems: actionItems,
        verificationCandidates: verificationCandidates,
      ),
      reviewSignalCount: actionItems.length + verificationCandidates.length,
      searchableText: [
        normalizedTitle,
        normalizedSummary,
        ...timelineEntries.map((entry) => entry.text.toLowerCase()),
      ].join(' ').toLowerCase(),
      fullTranscript: timelineEntries
          .map((entry) => '${entry.displayLabel}: ${entry.text}')
          .join('\n\n'),
      isFavorite: isFavorite,
      costSmartUsdMicros: costSmartUsdMicros,
      costLightUsdMicros: costLightUsdMicros,
      costTranscriptionUsdMicros: costTranscriptionUsdMicros,
      costTotalUsdMicros: costTotalUsdMicros,
    );
  }

  final String id;
  final List<ConversationTurn> turns;
  final List<SessionTimelineEntry> timelineEntries;
  final String modeLabel;
  final String profileId;
  final String profileLabel;
  final DateTime startedAt;
  final Duration duration;
  final String summaryTitle;
  final String summaryBody;
  final String promptPreview;
  final String answerPreview;
  final int assistantCount;
  final List<String> actionItems;
  final List<String> verificationCandidates;
  final String reviewBrief;
  final int reviewSignalCount;
  final String searchableText;
  final String fullTranscript;
  final bool isFavorite;
  final int? costSmartUsdMicros;
  final int? costLightUsdMicros;
  final int? costTranscriptionUsdMicros;
  final int? costTotalUsdMicros;

  int get turnCount => turns.length;
  bool get hasActionItems => actionItems.isNotEmpty;
  bool get hasFactCheckFlags => verificationCandidates.isNotEmpty;

  AssistantSessionMeta copyWith({bool? isFavorite}) {
    return AssistantSessionMeta(
      id: id,
      turns: turns,
      timelineEntries: timelineEntries,
      modeLabel: modeLabel,
      profileId: profileId,
      profileLabel: profileLabel,
      startedAt: startedAt,
      duration: duration,
      summaryTitle: summaryTitle,
      summaryBody: summaryBody,
      promptPreview: promptPreview,
      answerPreview: answerPreview,
      assistantCount: assistantCount,
      actionItems: actionItems,
      verificationCandidates: verificationCandidates,
      reviewBrief: reviewBrief,
      reviewSignalCount: reviewSignalCount,
      searchableText: searchableText,
      fullTranscript: fullTranscript,
      isFavorite: isFavorite ?? this.isFavorite,
      costSmartUsdMicros: costSmartUsdMicros,
      costLightUsdMicros: costLightUsdMicros,
      costTranscriptionUsdMicros: costTranscriptionUsdMicros,
      costTotalUsdMicros: costTotalUsdMicros,
    );
  }

  static String _modeLabel(String? mode) {
    return storedConversationModeLabel(mode);
  }

  static String _compactLine(String text, {int maxLength = 80}) {
    final normalized = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (normalized.length <= maxLength) return normalized;
    return '${normalized.substring(0, maxLength - 1)}...';
  }

  static String _summaryBody(List<ConversationTurn> turns) {
    return turns
        .take(3)
        .map(
          (turn) =>
              '${turn.role == 'user' ? 'You' : 'Even AI'}: ${_compactLine(turn.content, maxLength: 96)}',
        )
        .join('  ');
  }

  static String _timelineSummaryBody(
    List<SessionTimelineEntry> timelineEntries,
  ) {
    return timelineEntries
        .take(3)
        .map(
          (entry) =>
              '${entry.displayLabel}: ${_compactLine(entry.text, maxLength: 96)}',
        )
        .join('  ');
  }

  static String _buildReviewBrief({
    required String summaryTitle,
    required String summaryBody,
    required List<String> actionItems,
    required List<String> verificationCandidates,
  }) {
    final sections = <String>[];
    if (summaryTitle.trim().isNotEmpty) {
      sections.add('Summary: ${summaryTitle.trim()}');
    }
    if (summaryBody.trim().isNotEmpty &&
        summaryBody.trim() != summaryTitle.trim()) {
      sections.add(summaryBody.trim());
    }
    if (actionItems.isNotEmpty) {
      sections.add(
        'Action items:\n${actionItems.map((item) => '- $item').join('\n')}',
      );
    }
    if (verificationCandidates.isNotEmpty) {
      sections.add(
        'Verification candidates:\n${verificationCandidates.map((item) => '- $item').join('\n')}',
      );
    }
    return sections.join('\n\n').trim();
  }

  static List<String> _extractActionItems(List<ConversationTurn> turns) {
    final results = <String>[];
    for (final turn in turns) {
      for (final segment in turn.content.split(RegExp(r'[\n.!?。！？]+'))) {
        final trimmed = segment.trim();
        if (trimmed.isEmpty) continue;
        final lower = trimmed.toLowerCase();
        if (_actionHints.any((hint) => lower.contains(hint))) {
          results.add(trimmed);
        }
        if (results.length == 3) return results;
      }
    }
    return results;
  }

  static List<String> _extractVerificationCandidates(
    List<ConversationTurn> turns,
  ) {
    final results = <String>[];
    for (final turn in turns) {
      for (final segment in turn.content.split(RegExp(r'[\n.!?。！？]+'))) {
        final trimmed = segment.trim();
        if (trimmed.isEmpty) continue;
        final lower = trimmed.toLowerCase();
        final hasDigits = RegExp(r'\d').hasMatch(trimmed);
        if (hasDigits || _factCheckHints.any((hint) => lower.contains(hint))) {
          results.add(trimmed);
        }
        if (results.length == 3) return results;
      }
    }
    return results;
  }

  static const List<String> _actionHints = [
    'review',
    'schedule',
    'prepare',
    'follow up',
    'follow-up',
    'send',
    'draft',
    'confirm',
    'share',
    'check',
    'create',
    'write',
    '安排',
    '准备',
    '确认',
    '跟进',
    '发送',
    '检查',
    '整理',
  ];

  static const List<String> _factCheckHints = [
    'fact',
    'verify',
    'verified',
    'according to',
    'research',
    'reported',
    'study',
    'statistic',
    'data',
    'claim',
    'true',
    'false',
    '事实',
    '核实',
    '数据',
    '研究',
    '统计',
    '报道',
  ];
}

class SessionTimelineEntry {
  const SessionTimelineEntry({
    required this.speakerLabel,
    required this.text,
    required this.timestamp,
  });

  factory SessionTimelineEntry.fromTurn(ConversationTurn turn) {
    return SessionTimelineEntry(
      speakerLabel: turn.role == 'assistant' ? 'assistant' : 'user',
      text: turn.content,
      timestamp: turn.timestamp,
    );
  }

  final String speakerLabel;
  final String text;
  final DateTime timestamp;

  String get _normalizedSpeaker => speakerLabel.toLowerCase().trim();

  bool get isAssistant => _normalizedSpeaker == 'assistant';

  bool get isWearer =>
      _normalizedSpeaker == 'me' ||
      _normalizedSpeaker == 'user' ||
      _normalizedSpeaker == 'wearer';

  String get displayLabel {
    if (isAssistant) {
      return 'Even AI';
    }
    if (isWearer) {
      return 'You';
    }
    if (_normalizedSpeaker == 'other') {
      return 'Other';
    }
    return 'Conversation';
  }
}
