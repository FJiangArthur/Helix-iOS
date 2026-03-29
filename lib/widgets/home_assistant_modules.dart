import 'package:flutter/material.dart';

import '../models/assistant_profile.dart';
import '../services/conversation_engine.dart';
import '../theme/helix_theme.dart';
import 'glass_card.dart';

enum AssistantQuickAskPreset { concise, speakForMe, interview, factCheck }

extension AssistantQuickAskPresetX on AssistantQuickAskPreset {
  String label(bool isChinese) {
    switch (this) {
      case AssistantQuickAskPreset.concise:
        return isChinese ? '简洁' : 'Concise';
      case AssistantQuickAskPreset.speakForMe:
        return isChinese ? '替我说' : 'Speak For Me';
      case AssistantQuickAskPreset.interview:
        return isChinese ? '面试' : 'Interview';
      case AssistantQuickAskPreset.factCheck:
        return isChinese ? '核实' : 'Fact Check';
    }
  }

  String description(bool isChinese) {
    switch (this) {
      case AssistantQuickAskPreset.concise:
        return isChinese
            ? '默认短答，最快可用。'
            : 'Default short answer for the fastest handoff.';
      case AssistantQuickAskPreset.speakForMe:
        return isChinese
            ? '改成适合直接说出口的表达。'
            : 'Rewrite it as something you can say directly.';
      case AssistantQuickAskPreset.interview:
        return isChinese
            ? '压缩成有说服力的面试表达。'
            : 'Compress it into a persuasive interview answer.';
      case AssistantQuickAskPreset.factCheck:
        return isChinese
            ? '优先核实关键事实和风险。'
            : 'Prioritize verification and risky claims.';
    }
  }

  IconData get icon {
    switch (this) {
      case AssistantQuickAskPreset.concise:
        return Icons.flash_on_rounded;
      case AssistantQuickAskPreset.speakForMe:
        return Icons.record_voice_over_outlined;
      case AssistantQuickAskPreset.interview:
        return Icons.badge_outlined;
      case AssistantQuickAskPreset.factCheck:
        return Icons.fact_check_outlined;
    }
  }
}

class AssistantInsightSnapshot {
  AssistantInsightSnapshot({
    required this.summary,
    required this.topics,
    required this.actionItems,
    required this.sentiment,
    required this.verificationCandidates,
    required this.recommendedNextMove,
  });

  final String summary;
  final List<String> topics;
  final List<String> actionItems;
  final String sentiment;
  final List<String> verificationCandidates;
  final String recommendedNextMove;

  String get focusPrompt => recommendedNextMove;

  bool get hasContent =>
      summary.isNotEmpty ||
      topics.isNotEmpty ||
      actionItems.isNotEmpty ||
      sentiment.isNotEmpty ||
      verificationCandidates.isNotEmpty ||
      recommendedNextMove.isNotEmpty;

  /// Create an [AssistantInsightSnapshot] from a raw LLM JSON response.
  static AssistantInsightSnapshot? fromLlmResponse(Map<String, dynamic> json) {
    try {
      return AssistantInsightSnapshot(
        summary: json['summary'] as String? ?? '',
        topics: (json['topics'] as List<dynamic>?)?.cast<String>() ?? [],
        actionItems:
            (json['actionItems'] as List<dynamic>?)?.cast<String>() ?? [],
        sentiment: json['sentiment'] as String? ?? '',
        verificationCandidates: [],
        recommendedNextMove: '',
      );
    } catch (_) {
      return null;
    }
  }

  static AssistantInsightSnapshot? fromConversation({
    required String transcription,
    required String aiResponse,
    required List<ConversationTurn> history,
    required bool isChinese,
  }) {
    if (transcription.trim().isEmpty && aiResponse.trim().isEmpty) {
      return null;
    }

    final source = '${transcription.trim()} ${aiResponse.trim()}'.trim();
    final topics = _extractTopics(source);
    final actionItems = _extractActionItems(source);
    final sentiment = _sentimentFor(source, isChinese);
    final verificationCandidates = _extractVerificationCandidates(source);
    final recommendedNextMove = _recommendedNextMoveFor(
      history,
      source,
      isChinese,
    );
    final summary = _summaryFor(
      transcription: transcription,
      aiResponse: aiResponse,
      isChinese: isChinese,
    );

    final snapshot = AssistantInsightSnapshot(
      summary: summary,
      topics: topics,
      actionItems: actionItems,
      sentiment: sentiment,
      verificationCandidates: verificationCandidates,
      recommendedNextMove: recommendedNextMove,
    );
    return snapshot.hasContent ? snapshot : null;
  }

  static List<String> _extractTopics(String source) {
    final clean = source
        .replaceAll(RegExp(r'[^A-Za-z0-9\u4e00-\u9fff\s]'), ' ')
        .toLowerCase();
    final words = clean
        .split(RegExp(r'\s+'))
        .where((word) => word.length > 3)
        .where(
          (word) => !_stopWords.contains(word) && !_numericOnly.hasMatch(word),
        )
        .toList();
    final counts = <String, int>{};
    for (final word in words) {
      counts[word] = (counts[word] ?? 0) + 1;
    }
    final ranked = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return ranked.take(4).map((entry) => _titleize(entry.key)).toList();
  }

  static List<String> _extractActionItems(String source) {
    final rawSegments = source
        .split(RegExp(r'[\n.!?。！？]+'))
        .map((segment) => segment.trim())
        .where((segment) => segment.isNotEmpty);
    final results = <String>[];
    for (final segment in rawSegments) {
      final lower = segment.toLowerCase();
      if (_actionHints.any((hint) => lower.contains(hint))) {
        results.add(segment);
      }
      if (results.length == 3) break;
    }
    return results;
  }

  static List<String> _extractVerificationCandidates(String source) {
    final rawSegments = source
        .split(RegExp(r'[\n.!?。！？]+'))
        .map((segment) => segment.trim())
        .where((segment) => segment.isNotEmpty);
    final results = <String>[];
    for (final segment in rawSegments) {
      final lower = segment.toLowerCase();
      final hasDigits = RegExp(r'\d').hasMatch(segment);
      if (hasDigits || _verificationHints.any((hint) => lower.contains(hint))) {
        results.add(segment);
      }
      if (results.length == 3) break;
    }
    return results;
  }

  static String _summaryFor({
    required String transcription,
    required String aiResponse,
    required bool isChinese,
  }) {
    final source = aiResponse.trim().isNotEmpty
        ? aiResponse.trim()
        : transcription.trim();
    if (source.isEmpty) return '';
    final compact = source.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (compact.length <= 120) return compact;
    final prefix = isChinese ? '核心摘要：' : 'Core summary: ';
    return '$prefix${compact.substring(0, 116)}...';
  }

  static String _sentimentFor(String source, bool isChinese) {
    final lower = source.toLowerCase();
    final positive = _positiveHints.where((hint) => lower.contains(hint)).length;
    final caution = _cautionHints.where((hint) => lower.contains(hint)).length;
    if (caution > positive) {
      return isChinese ? '谨慎 / 有风险' : 'Cautious / Risky';
    }
    if (positive > 0) {
      return isChinese ? '积极 / 顺畅' : 'Positive / Smooth';
    }
    return isChinese ? '中性 / 信息型' : 'Neutral / Informational';
  }

  static String _recommendedNextMoveFor(
    List<ConversationTurn> history,
    String source,
    bool isChinese,
  ) {
    if (_extractVerificationCandidates(source).isNotEmpty) {
      return isChinese
          ? '先核实带数字或来源的说法，再继续给结论。'
          : 'Verify the numeric or sourced claims before committing to the answer.';
    }

    final recent = history.reversed.take(4).toList();
    ConversationTurn? userTurn;
    for (final turn in recent) {
      if (turn.role == 'user') {
        userTurn = turn;
        break;
      }
    }
    if (userTurn == null || userTurn.content.trim().isEmpty) {
      return isChinese
          ? '继续追问最关键的细节。'
          : 'Push on the most decision-relevant detail next.';
    }
    return isChinese
        ? '围绕“${_compact(userTurn.content, 24)}”补一个具体例子。'
        : 'Add one concrete example around "${_compact(userTurn.content, 24)}".';
  }

  static String _compact(String text, int maxLength) {
    final compact = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (compact.length <= maxLength) return compact;
    return '${compact.substring(0, maxLength - 1)}...';
  }

  static String _titleize(String value) {
    if (value.isEmpty) return value;
    return value[0].toUpperCase() + value.substring(1);
  }

  static final RegExp _numericOnly = RegExp(r'^\d+$');

  static const Set<String> _stopWords = {
    'this',
    'that',
    'with',
    'from',
    'have',
    'into',
    'your',
    'about',
    'would',
    'could',
    'should',
    'there',
    'their',
    'while',
    'because',
    'they',
    'them',
    'what',
    'when',
    'where',
    'which',
    'will',
    'just',
    'than',
    'then',
    'been',
    'more',
    'like',
    'some',
    'very',
    'need',
    'after',
    'before',
    'through',
    'http',
    'https',
  };

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

  static const List<String> _verificationHints = [
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
    'benchmark',
    'facts',
    '事实',
    '核实',
    '数据',
    '研究',
    '统计',
    '报道',
    '来源',
  ];

  static const List<String> _positiveHints = [
    'great',
    'good',
    'strong',
    'clear',
    'opportunity',
    'confident',
    'positive',
    'promising',
    '顺利',
    '积极',
    '清晰',
    '机会',
  ];

  static const List<String> _cautionHints = [
    'risk',
    'issue',
    'concern',
    'unclear',
    'blocked',
    'warning',
    'problem',
    'careful',
    '风险',
    '问题',
    '警告',
    '担心',
    '不明确',
  ];
}

class AssistantPresetStrip extends StatelessWidget {
  const AssistantPresetStrip({
    super.key,
    required this.selected,
    required this.onSelected,
    required this.isChinese,
  });

  final AssistantQuickAskPreset selected;
  final ValueChanged<AssistantQuickAskPreset> onSelected;
  final bool isChinese;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionCaption(
          label: isChinese ? '回答预设' : 'ANSWER PRESET',
          icon: Icons.tune_rounded,
        ),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: AssistantQuickAskPreset.values.map((preset) {
              final isSelected = preset == selected;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: GestureDetector(
                  onTap: () => onSelected(preset),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 9,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? HelixTheme.cyan.withValues(alpha: 0.14)
                          : Colors.white.withValues(alpha: 0.04),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: isSelected
                            ? HelixTheme.cyan.withValues(alpha: 0.26)
                            : Colors.white.withValues(alpha: 0.08),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          preset.icon,
                          size: 14,
                          color: isSelected
                              ? HelixTheme.cyan
                              : Colors.white.withValues(alpha: 0.5),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          preset.label(isChinese),
                          style: TextStyle(
                            color: isSelected
                                ? Colors.white
                                : Colors.white.withValues(alpha: 0.7),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}

class AssistantProfileStrip extends StatelessWidget {
  const AssistantProfileStrip({
    super.key,
    required this.profiles,
    required this.selectedProfileId,
    required this.onSelected,
    required this.isChinese,
    this.onEdit,
  });

  final List<AssistantProfile> profiles;
  final String selectedProfileId;
  final ValueChanged<AssistantProfile> onSelected;
  final bool isChinese;
  final ValueChanged<AssistantProfile>? onEdit;

  @override
  Widget build(BuildContext context) {
    if (profiles.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionCaption(
          label: isChinese ? '助手档案' : 'ASSISTANT PROFILE',
          icon: Icons.person_pin_circle_outlined,
        ),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: profiles.map((profile) {
              final isSelected = profile.id == selectedProfileId;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: GestureDetector(
                  onTap: () => onSelected(profile),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    width: 188,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? HelixTheme.purple.withValues(alpha: 0.16)
                          : Colors.white.withValues(alpha: 0.04),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isSelected
                            ? HelixTheme.purple.withValues(alpha: 0.34)
                            : Colors.white.withValues(alpha: 0.08),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                profile.name,
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.94),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            if (isSelected && onEdit != null)
                              GestureDetector(
                                onTap: () => onEdit!(profile),
                                child: Icon(
                                  Icons.edit_outlined,
                                  size: 14,
                                  color: HelixTheme.purple.withValues(
                                    alpha: 0.72,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          profile.description,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.58),
                            fontSize: 11,
                            height: 1.35,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          profile.answerStyle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: isSelected
                                ? HelixTheme.purple.withValues(alpha: 0.94)
                                : Colors.white.withValues(alpha: 0.72),
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}

class AssistantLoadoutCard extends StatelessWidget {
  const AssistantLoadoutCard({
    super.key,
    required this.profile,
    required this.preset,
    required this.isChinese,
    required this.autoShowSummary,
    required this.autoShowFollowUps,
    required this.backendLabel,
    required this.micLabel,
  });

  final AssistantProfile profile;
  final AssistantQuickAskPreset preset;
  final bool isChinese;
  final bool autoShowSummary;
  final bool autoShowFollowUps;
  final String backendLabel;
  final String micLabel;

  @override
  Widget build(BuildContext context) {
    final readiness = <Widget>[
      _MetaChip(
        label: profile.name,
        icon: Icons.person_outline_rounded,
        color: HelixTheme.purple,
      ),
      _MetaChip(
        label: preset.label(isChinese),
        icon: preset.icon,
        color: HelixTheme.cyan,
      ),
      _MetaChip(
        label: backendLabel,
        icon: Icons.hub_outlined,
        color: const Color(0xFFFFB74D),
      ),
      _MetaChip(
        label: micLabel,
        icon: Icons.mic_none_rounded,
        color: const Color(0xFF7CFFB2),
      ),
      if (profile.showSummaryTool)
        _TagChip(label: isChinese ? '摘要工具' : 'Summary Tool'),
      if (profile.showFollowUps)
        _TagChip(label: isChinese ? '追问推荐' : 'Follow-ups'),
      if (profile.showFactCheck)
        _TagChip(label: isChinese ? '事实核实' : 'Fact Check'),
      if (profile.showActionItems)
        _TagChip(label: isChinese ? '行动项' : 'Action Items'),
      if (autoShowSummary)
        _TagChip(label: isChinese ? '自动展开洞察' : 'Auto Insights'),
      if (autoShowFollowUps)
        _TagChip(label: isChinese ? '自动展开追问' : 'Auto Follow-ups'),
    ];

    return GlassCard(
      opacity: 0.08,
      borderColor: HelixTheme.cyan.withValues(alpha: 0.18),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionCaption(
            label: isChinese ? '当前配置' : 'READY STACK',
            icon: Icons.dashboard_customize_outlined,
          ),
          const SizedBox(height: 10),
          _NarrativeBlock(
            text: isChinese
                ? '风格：${profile.answerStyle}\n默认预设：${preset.description(true)}'
                : 'Style: ${profile.answerStyle}\nDefault preset: ${preset.description(false)}',
          ),
          const SizedBox(height: 10),
          Wrap(spacing: 8, runSpacing: 8, children: readiness),
        ],
      ),
    );
  }
}

class AssistantSettingsToggleTile extends StatelessWidget {
  const AssistantSettingsToggleTile({
    super.key,
    required this.title,
    required this.description,
    required this.value,
    required this.onTap,
  });

  final String title;
  final String description;
  final bool value;
  final Future<void> Function() onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.9),
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.58),
                      fontSize: 11,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Switch(
              value: value,
              activeThumbColor: HelixTheme.cyan,
              onChanged: (_) {
                onTap();
              },
            ),
          ],
        ),
      ),
    );
  }
}

class AssistantResponseActions extends StatelessWidget {
  const AssistantResponseActions({
    super.key,
    required this.isChinese,
    this.allowSummary = true,
    this.allowFactCheck = true,
    required this.isSummarizing,
    required this.onSummarize,
    required this.onRephrase,
    required this.onTranslate,
    required this.onFactCheck,
    required this.onSendToGlasses,
    required this.canSendToGlasses,
    this.followUpCount = 0,
    this.actionItemCount = 0,
    this.verificationCount = 0,
    this.onPinResponse,
    this.onPinFollowUp,
    this.onStarInsight,
  });

  final bool isChinese;
  final bool allowSummary;
  final bool allowFactCheck;
  final bool isSummarizing;
  final VoidCallback onSummarize;
  final VoidCallback onRephrase;
  final VoidCallback onTranslate;
  final VoidCallback onFactCheck;
  final VoidCallback onSendToGlasses;
  final bool canSendToGlasses;
  final int followUpCount;
  final int actionItemCount;
  final int verificationCount;
  final VoidCallback? onPinResponse;
  final VoidCallback? onPinFollowUp;
  final VoidCallback? onStarInsight;

  @override
  Widget build(BuildContext context) {
    final readiness = <Widget>[];
    if (followUpCount > 0) {
      readiness.add(
        _MetaChip(
          label: isChinese ? '追问 $followUpCount' : '$followUpCount follow-ups',
          icon: Icons.forum_outlined,
          color: HelixTheme.purple,
        ),
      );
    }
    if (actionItemCount > 0) {
      readiness.add(
        _MetaChip(
          label: isChinese
              ? '行动项 $actionItemCount'
              : '$actionItemCount action items',
          icon: Icons.checklist_rounded,
          color: const Color(0xFF7CFFB2),
        ),
      );
    }
    if (verificationCount > 0) {
      readiness.add(
        _MetaChip(
          label: isChinese
              ? '待核实 $verificationCount'
              : '$verificationCount verify',
          icon: Icons.fact_check_outlined,
          color: const Color(0xFFFFB74D),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionCaption(
          label: isChinese ? '回答工具' : 'RESPONSE TOOLS',
          icon: Icons.bolt_rounded,
        ),
        if (readiness.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8, children: readiness),
        ],
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            if (allowSummary)
              _ActionChip(
                icon: Icons.summarize_outlined,
                label: isSummarizing
                    ? (isChinese ? '摘要中...' : 'Summarizing...')
                    : (isChinese ? '摘要' : 'Summarize'),
                onTap: isSummarizing ? null : onSummarize,
              ),
            _ActionChip(
              icon: Icons.record_voice_over_outlined,
              label: isChinese ? '替我表达' : 'Rephrase',
              onTap: onRephrase,
            ),
            _ActionChip(
              icon: Icons.translate_rounded,
              label: isChinese ? '翻译' : 'Translate',
              onTap: onTranslate,
            ),
            if (allowFactCheck)
              _ActionChip(
                icon: Icons.fact_check_outlined,
                label: isChinese ? '核实' : 'Fact Check',
                onTap: onFactCheck,
              ),
            _ActionChip(
              icon: Icons.visibility_outlined,
              label: isChinese ? '发到眼镜' : 'Send to Glasses',
              onTap: canSendToGlasses ? onSendToGlasses : null,
            ),
            if (onPinResponse != null)
              _ActionChip(
                icon: Icons.push_pin_outlined,
                label: isChinese ? '固定回答' : 'Pin Answer',
                onTap: onPinResponse,
              ),
            if (onPinFollowUp != null)
              _ActionChip(
                icon: Icons.bookmark_add_outlined,
                label: isChinese ? '固定追问' : 'Pin Follow-up',
                onTap: onPinFollowUp,
              ),
            if (onStarInsight != null)
              _ActionChip(
                icon: Icons.star_border_rounded,
                label: isChinese ? '标记洞察' : 'Star Insight',
                onTap: onStarInsight,
              ),
          ],
        ),
      ],
    );
  }
}

class AssistantInsightsCard extends StatelessWidget {
  const AssistantInsightsCard({
    super.key,
    required this.snapshot,
    required this.isChinese,
  });

  final AssistantInsightSnapshot snapshot;
  final bool isChinese;

  @override
  Widget build(BuildContext context) {
    if (!snapshot.hasContent) {
      return const SizedBox.shrink();
    }

    return GlassCard(
      opacity: 0.09,
      borderColor: HelixTheme.cyan.withValues(alpha: 0.18),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionCaption(
            label: isChinese ? '语义洞察' : 'INSIGHTS',
            icon: Icons.insights_outlined,
          ),
          if (snapshot.summary.isNotEmpty) ...[
            const SizedBox(height: 10),
            _InsightLabel(label: isChinese ? 'Summary' : 'Summary'),
            const SizedBox(height: 6),
            _NarrativeBlock(text: snapshot.summary),
          ],
          if (snapshot.topics.isNotEmpty) ...[
            const SizedBox(height: 12),
            _InsightLabel(label: isChinese ? 'Topics' : 'Topics'),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: snapshot.topics
                  .map((topic) => _TagChip(label: topic))
                  .toList(),
            ),
          ],
          if (snapshot.actionItems.isNotEmpty) ...[
            const SizedBox(height: 12),
            _InsightLabel(label: isChinese ? 'Action Items' : 'Action Items'),
            const SizedBox(height: 6),
            ...snapshot.actionItems.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: _BulletLine(
                  icon: Icons.arrow_right_rounded,
                  color: HelixTheme.cyan,
                  text: item,
                ),
              ),
            ),
          ],
          if (snapshot.verificationCandidates.isNotEmpty) ...[
            const SizedBox(height: 12),
            _InsightLabel(
              label: isChinese
                  ? 'Verification Candidates'
                  : 'Verification Candidates',
            ),
            const SizedBox(height: 6),
            ...snapshot.verificationCandidates.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: _BulletLine(
                  icon: Icons.verified_outlined,
                  color: const Color(0xFFFFB74D),
                  text: item,
                ),
              ),
            ),
          ],
          if (snapshot.sentiment.isNotEmpty ||
              snapshot.recommendedNextMove.isNotEmpty) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                if (snapshot.sentiment.isNotEmpty)
                  Expanded(
                    child: _MetricTile(
                      label: isChinese ? 'Sentiment' : 'Sentiment',
                      value: snapshot.sentiment,
                    ),
                  ),
                if (snapshot.sentiment.isNotEmpty &&
                    snapshot.recommendedNextMove.isNotEmpty)
                  const SizedBox(width: 10),
                if (snapshot.recommendedNextMove.isNotEmpty)
                  Expanded(
                    child: _MetricTile(
                      label: isChinese ? 'Next Move' : 'Next Move',
                      value: snapshot.recommendedNextMove,
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _SectionCaption extends StatelessWidget {
  const _SectionCaption({required this.label, required this.icon});

  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 14, color: HelixTheme.cyan.withValues(alpha: 0.7)),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            color: HelixTheme.cyan.withValues(alpha: 0.65),
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.1,
          ),
        ),
      ],
    );
  }
}

class _InsightLabel extends StatelessWidget {
  const _InsightLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: TextStyle(
        color: Colors.white.withValues(alpha: 0.58),
        fontSize: 12,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

class _TagChip extends StatelessWidget {
  const _TagChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.72),
          fontSize: 12,
        ),
      ),
    );
  }
}

class _NarrativeBlock extends StatelessWidget {
  const _NarrativeBlock({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.82),
          fontSize: 13,
          height: 1.45,
        ),
      ),
    );
  }
}

class _BulletLine extends StatelessWidget {
  const _BulletLine({
    required this.icon,
    required this.color,
    required this.text,
  });

  final IconData icon;
  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: color.withValues(alpha: 0.82)),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.76),
              fontSize: 13,
              height: 1.35,
            ),
          ),
        ),
      ],
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.45),
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.8),
              fontSize: 12,
              height: 1.35,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({
    required this.label,
    required this.icon,
    required this.color,
  });

  final String label;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.24)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionChip extends StatelessWidget {
  const _ActionChip({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final isEnabled = onTap != null;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 160),
        opacity: isEnabled ? 1 : 0.45,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: isEnabled
                  ? Colors.white.withValues(alpha: 0.1)
                  : Colors.white.withValues(alpha: 0.06),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 14,
                color: isEnabled
                    ? HelixTheme.cyan.withValues(alpha: 0.8)
                    : Colors.white.withValues(alpha: 0.4),
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.72),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
