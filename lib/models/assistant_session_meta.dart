import '../services/conversation_engine.dart';
import 'assistant_profile.dart';

class AssistantSessionMeta {
  AssistantSessionMeta({
    required this.id,
    required this.turns,
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
    required this.searchableText,
    required this.fullTranscript,
    this.isFavorite = false,
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
        .firstWhere(
          (value) => value.isNotEmpty,
          orElse: () => 'general',
        );
    final profile = AssistantProfile.normalize(profiles).firstWhere(
      (candidate) => candidate.id == profileId,
      orElse: () => AssistantProfile.fallback(profileId),
    );
    final summaryTitle = firstAssistant != null
        ? _compactLine(firstAssistant.content, maxLength: 72)
        : _compactLine(firstUser.content, maxLength: 72);

    return AssistantSessionMeta(
      id: '${first.timestamp.millisecondsSinceEpoch}-${turns.length}',
      turns: turns,
      modeLabel: _modeLabel(first.mode),
      profileId: profile.id,
      profileLabel: profile.name,
      startedAt: first.timestamp,
      duration: last.timestamp.difference(first.timestamp),
      summaryTitle: summaryTitle,
      summaryBody: _summaryBody(turns),
      promptPreview: _compactLine(firstUser.content),
      answerPreview: _compactLine(
        firstAssistant?.content ?? turns.last.content,
      ),
      assistantCount: turns.where((turn) => turn.role == 'assistant').length,
      actionItems: _extractActionItems(turns),
      verificationCandidates: _extractVerificationCandidates(turns),
      searchableText: turns.map((turn) => turn.content.toLowerCase()).join(' '),
      fullTranscript: turns
          .map((turn) => '${turn.role == 'user' ? 'You' : 'Even AI'}: ${turn.content}')
          .join('\n\n'),
      isFavorite: isFavorite,
    );
  }

  final String id;
  final List<ConversationTurn> turns;
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
  final String searchableText;
  final String fullTranscript;
  final bool isFavorite;

  int get turnCount => turns.length;
  bool get hasActionItems => actionItems.isNotEmpty;
  bool get hasFactCheckFlags => verificationCandidates.isNotEmpty;

  AssistantSessionMeta copyWith({bool? isFavorite}) {
    return AssistantSessionMeta(
      id: id,
      turns: turns,
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
      searchableText: searchableText,
      fullTranscript: fullTranscript,
      isFavorite: isFavorite ?? this.isFavorite,
    );
  }

  static String _modeLabel(String? mode) {
    if (mode == null || mode.isEmpty) return 'General';
    return mode[0].toUpperCase() + mode.substring(1).toLowerCase();
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

  static List<String> _extractVerificationCandidates(List<ConversationTurn> turns) {
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
