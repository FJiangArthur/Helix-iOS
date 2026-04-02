import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/assistant_session_meta.dart';
import '../services/conversation_engine.dart';
import '../services/database/helix_database.dart';
import '../services/history_session_loader.dart';
import '../services/settings_manager.dart';
import '../theme/helix_theme.dart';
import '../utils/i18n.dart';
import '../utils/transcript_timestamps.dart';
import '../widgets/glass_card.dart';

class ConversationHistoryScreen extends StatefulWidget {
  const ConversationHistoryScreen({super.key});

  @override
  State<ConversationHistoryScreen> createState() =>
      _ConversationHistoryScreenState();
}

class _ConversationHistoryScreenState extends State<ConversationHistoryScreen> {
  final _engine = ConversationEngine.instance;
  final List<StreamSubscription> _subs = [];
  static const List<String> _modeFilterKeys = [
    'All',
    'General',
    'Interview',
    'Answer All',
    'Answer On-demand',
  ];
  static const List<String> _libraryFilterKeys = [
    'All',
    'Favorites',
    'Action Items',
    'Fact-check Flags',
  ];

  static String _modeFilterLabel(String key) => switch (key) {
    'All' => tr('All', '全部'),
    'General' => tr('General', '通用'),
    'Interview' => tr('Interview', '面试'),
    'Answer All' => tr('Answer All', '全程回答'),
    'Answer On-demand' => tr('Answer On-demand', '按需回答'),
    _ => key,
  };

  static String _libraryFilterLabel(String key) => switch (key) {
    'All' => tr('All', '全部'),
    'Favorites' => tr('Favorites', '收藏'),
    'Action Items' => tr('Action Items', '待办事项'),
    'Fact-check Flags' => tr('Fact-check Flags', '事实核查'),
    _ => key,
  };
  static const String _favoriteKey = 'historyFavoriteSessionIds';

  List<AssistantSessionMeta> _sessions = [];
  List<AssistantSessionMeta> _filteredSessions = [];
  final Set<String> _expandedSessionIds = <String>{};
  final Set<String> _favoriteSessionIds = <String>{};
  String _searchQuery = '';
  String _selectedMode = 'All';
  String _selectedLibraryFilter = 'All';
  bool _searchExpanded = false;
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _loadFavoritesAndHistory();
    _subs.add(
      _engine.sessionSavedStream.listen((_) {
        if (!mounted) return;
        _loadHistory();
      }),
    );
  }

  @override
  void dispose() {
    for (final sub in _subs) {
      sub.cancel();
    }
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  Future<void> _loadFavoritesAndHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final favoriteIds = prefs.getStringList(_favoriteKey) ?? const <String>[];
    final persistedSessions = await HistorySessionLoader.loadPersistedSessions(
      favoriteIds: favoriteIds,
    );
    if (!mounted) return;
    setState(() {
      _favoriteSessionIds
        ..clear()
        ..addAll(favoriteIds);
      _sessions = persistedSessions;
      _applyFilters();
    });
  }

  Future<void> _persistFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_favoriteKey, _favoriteSessionIds.toList());
  }

  Future<void> _loadHistory() async {
    final persistedSessions = await HistorySessionLoader.loadPersistedSessions(
      favoriteIds: _favoriteSessionIds.toList(),
    );
    if (!mounted) return;
    setState(() {
      _sessions = persistedSessions;
      _applyFilters();
    });
  }

  void _applyFilters() {
    _filteredSessions = _sessions.where((session) {
      if (_selectedMode != 'All' && session.modeLabel != _selectedMode) {
        return false;
      }
      if (_selectedLibraryFilter == 'Favorites' && !session.isFavorite) {
        return false;
      }
      if (_selectedLibraryFilter == 'Action Items' && !session.hasActionItems) {
        return false;
      }
      if (_selectedLibraryFilter == 'Fact-check Flags' &&
          !session.hasFactCheckFlags) {
        return false;
      }
      if (_searchQuery.isNotEmpty &&
          !session.searchableText.contains(_searchQuery.toLowerCase())) {
        return false;
      }
      return true;
    }).toList();
  }

  void _onSearchChanged(String query) {
    setState(() {
      _searchQuery = query;
      _applyFilters();
    });
  }

  void _onModeSelected(String mode) {
    setState(() {
      _selectedMode = mode;
      _applyFilters();
    });
  }

  void _onLibraryFilterSelected(String filter) {
    setState(() {
      _selectedLibraryFilter = filter;
      _applyFilters();
    });
  }

  void _copyToClipboard(String value, String label) {
    Clipboard.setData(ClipboardData(text: value));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(tr('$label copied', '$label 已复制')),
        backgroundColor: HelixTheme.surface,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _toggleFavorite(AssistantSessionMeta session) async {
    setState(() {
      if (_favoriteSessionIds.contains(session.id)) {
        _favoriteSessionIds.remove(session.id);
      } else {
        _favoriteSessionIds.add(session.id);
      }
      _sessions = _sessions
          .map(
            (item) => item.id == session.id
                ? item.copyWith(
                    isFavorite: _favoriteSessionIds.contains(item.id),
                  )
                : item,
          )
          .toList();
      _applyFilters();
    });
    await _persistFavorites();
  }

  void _toggleExpanded(AssistantSessionMeta session) {
    setState(() {
      if (_expandedSessionIds.contains(session.id)) {
        _expandedSessionIds.remove(session.id);
      } else {
        _expandedSessionIds.add(session.id);
      }
    });
  }

  void _clearHistory() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: HelixTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          tr('Clear History', '清除历史'),
          style: const TextStyle(color: Colors.white),
        ),
        content: Text(
          tr(
            'Are you sure you want to clear all conversation history? This cannot be undone.',
            '确定要清除所有对话历史吗？此操作无法撤销。',
          ),
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              tr('Cancel', '取消'),
              style: const TextStyle(color: Colors.white54),
            ),
          ),
          TextButton(
            onPressed: () {
              ConversationEngine.instance.clearHistory();
              unawaited(
                Future.wait([
                  HelixDatabase.instance.customStatement(
                    'DELETE FROM conversation_ai_cost_entries',
                  ),
                  HelixDatabase.instance.customStatement('DELETE FROM topics'),
                  HelixDatabase.instance.customStatement(
                    'DELETE FROM conversation_segments',
                  ),
                  HelixDatabase.instance.customStatement(
                    'DELETE FROM conversations',
                  ),
                ]),
              );
              _searchController.clear();
              _searchQuery = '';
              _searchExpanded = false;
              _selectedMode = 'All';
              _selectedLibraryFilter = 'All';
              _expandedSessionIds.clear();
              unawaited(_loadHistory());
              Navigator.of(context).pop();
            },
            child: Text(
              tr('Clear', '清除'),
              style: const TextStyle(color: Colors.redAccent),
            ),
          ),
        ],
      ),
    );
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final diff = now.difference(timestamp);

    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) {
      final h = timestamp.hour > 12 ? timestamp.hour - 12 : timestamp.hour;
      final ampm = timestamp.hour >= 12 ? 'PM' : 'AM';
      return '${h == 0 ? 12 : h}:${timestamp.minute.toString().padLeft(2, '0')} $ampm';
    }
    if (diff.inDays < 7) {
      const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      final h = timestamp.hour > 12 ? timestamp.hour - 12 : timestamp.hour;
      final ampm = timestamp.hour >= 12 ? 'PM' : 'AM';
      return '${days[timestamp.weekday - 1]} ${h == 0 ? 12 : h}:${timestamp.minute.toString().padLeft(2, '0')} $ampm';
    }
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[timestamp.month - 1]} ${timestamp.day}';
  }

  String _formatDuration(Duration duration) {
    if (duration.inMinutes < 1) return '<1 min';
    if (duration.inHours < 1) return '${duration.inMinutes} min';
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    if (minutes == 0) return '${hours}h';
    return '${hours}h ${minutes}m';
  }

  Color _modeColor(String? mode) {
    switch ((mode ?? '').trim().toLowerCase()) {
      case 'interview':
        return HelixTheme.purple;
      case 'passive':
      case 'answer all':
        return const Color(0xFF00FF88);
      case 'proactive':
      case 'answer on-demand':
        return HelixTheme.amber;
      case 'general':
      default:
        return HelixTheme.cyan;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HelixTheme.background,
      body: SafeArea(
        child: Column(
          children: [
            _buildCompactHeader(),
            _buildCollapsibleSearchBar(),
            _buildCombinedFilterChips(),
            Expanded(
              child: _sessions.isEmpty
                  ? _buildEmptyState()
                  : _filteredSessions.isEmpty
                  ? _buildNoResultsState()
                  : _buildHistoryList(),
            ),
            if (_sessions.isNotEmpty) _buildClearButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildCompactHeader() {
    final totalSessions = _sessions.length;
    final favoriteSessions = _sessions
        .where((session) => session.isFavorite)
        .length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
      child: Row(
        children: [
          Text(
            tr('Sessions', '会话'),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            tr(
              '$totalSessions sessions · $favoriteSessions fav',
              '$totalSessions 个会话 · $favoriteSessions 收藏',
            ),
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.42),
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          const Spacer(),
          IconButton(
            onPressed: () {
              setState(() {
                _searchExpanded = !_searchExpanded;
                if (!_searchExpanded) {
                  _searchController.clear();
                  _onSearchChanged('');
                  _searchFocusNode.unfocus();
                }
              });
            },
            icon: Icon(
              _searchExpanded ? Icons.search_off_rounded : Icons.search_rounded,
              color: _searchExpanded
                  ? HelixTheme.cyan
                  : Colors.white.withValues(alpha: 0.54),
              size: 22,
            ),
            splashRadius: 18,
          ),
        ],
      ),
    );
  }

  Widget _buildCollapsibleSearchBar() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
      height: _searchExpanded ? 52 : 0,
      clipBehavior: Clip.hardEdge,
      decoration: const BoxDecoration(),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
        child: GlassCard(
          borderRadius: 16,
          borderColor: HelixTheme.cyan.withValues(alpha: 0.18),
          opacity: 0.08,
          padding: EdgeInsets.zero,
          child: TextField(
            controller: _searchController,
            focusNode: _searchFocusNode,
            onChanged: _onSearchChanged,
            style: const TextStyle(color: Colors.white, fontSize: 15),
            cursorColor: HelixTheme.cyan,
            decoration: InputDecoration(
              hintText: tr(
                'Search sessions, prompts, answers...',
                '搜索会话、提示、回答...',
              ),
              hintStyle: TextStyle(
                color: Colors.white.withValues(alpha: 0.34),
                fontSize: 15,
              ),
              prefixIcon: Icon(
                Icons.search_rounded,
                color: HelixTheme.cyan.withValues(alpha: 0.68),
                size: 22,
              ),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: Icon(
                        Icons.close_rounded,
                        color: Colors.white.withValues(alpha: 0.48),
                        size: 20,
                      ),
                      onPressed: () {
                        _searchController.clear();
                        _onSearchChanged('');
                        _searchFocusNode.unfocus();
                      },
                    )
                  : null,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 15,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCombinedFilterChips() {
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          // Mode filter chips
          for (var i = 0; i < _modeFilterKeys.length; i++) ...[
            if (i > 0) const SizedBox(width: 8),
            _buildChip(
              label: _modeFilterLabel(_modeFilterKeys[i]),
              isSelected: _selectedMode == _modeFilterKeys[i],
              color: _modeFilterKeys[i] == 'All'
                  ? HelixTheme.cyan
                  : _modeColor(_modeFilterKeys[i].toLowerCase()),
              onTap: () => _onModeSelected(_modeFilterKeys[i]),
            ),
          ],
          // Divider
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Center(
              child: Container(
                width: 1,
                height: 20,
                color: Colors.white.withValues(alpha: 0.12),
              ),
            ),
          ),
          // Library filter chips
          for (var i = 0; i < _libraryFilterKeys.length; i++) ...[
            if (i > 0) const SizedBox(width: 8),
            _buildChip(
              label: _libraryFilterLabel(_libraryFilterKeys[i]),
              isSelected: _selectedLibraryFilter == _libraryFilterKeys[i],
              color: switch (_libraryFilterKeys[i]) {
                'Favorites' => const Color(0xFFFFC857),
                'Action Items' => const Color(0xFF7CFFB2),
                'Fact-check Flags' => const Color(0xFFFFA726),
                _ => HelixTheme.cyan,
              },
              onTap: () => _onLibraryFilterSelected(_libraryFilterKeys[i]),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildChip({
    required String label,
    required bool isSelected,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? color.withValues(alpha: 0.18)
              : Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? color.withValues(alpha: 0.56)
                : Colors.white.withValues(alpha: 0.12),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? color : Colors.white.withValues(alpha: 0.54),
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [
                    HelixTheme.cyan.withValues(alpha: 0.16),
                    HelixTheme.purple.withValues(alpha: 0.12),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                border: Border.all(
                  color: HelixTheme.cyan.withValues(alpha: 0.2),
                ),
              ),
              child: Icon(
                Icons.auto_stories_rounded,
                size: 40,
                color: HelixTheme.cyan.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 28),
            Text(
              tr('No Sessions Yet', '暂无会话'),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              tr(
                'Your assistant sessions will collect here as reusable conversation snapshots.',
                '您的助手会话将收集在此处，作为可复用的对话快照。',
              ),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.54),
                fontSize: 14,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 28),
            GlassCard(
              borderRadius: 16,
              borderColor: HelixTheme.cyan.withValues(alpha: 0.14),
              opacity: 0.06,
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _buildSuggestionRow(
                    Icons.mic_rounded,
                    tr(
                      'Start listening with the glasses connected.',
                      '连接眼镜后开始收听。',
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildSuggestionRow(
                    Icons.bolt_rounded,
                    tr(
                      'Use Quick Ask to generate a focused answer session.',
                      '使用快速提问生成专注的回答会话。',
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildSuggestionRow(
                    Icons.insights_outlined,
                    tr(
                      'Come back here to search and reuse past answers.',
                      '返回此处搜索和复用过去的回答。',
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSuggestionRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 18, color: HelixTheme.cyan.withValues(alpha: 0.66)),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.64),
              fontSize: 13,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNoResultsState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search_off_rounded,
            size: 56,
            color: Colors.white.withValues(alpha: 0.22),
          ),
          const SizedBox(height: 16),
          Text(
            tr('No matching sessions', '没有匹配的会话'),
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.58),
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            tr(
              'Try a different search term or library filter.',
              '尝试不同的搜索词或筛选条件。',
            ),
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.38),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryList() {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      itemCount: _filteredSessions.length,
      itemBuilder: (context, index) {
        final session = _filteredSessions[index];
        return _buildSessionCard(session);
      },
    );
  }

  Widget _buildSessionCard(AssistantSessionMeta session) {
    final modeColor = _modeColor(session.modeLabel.toLowerCase());
    final isExpanded = _expandedSessionIds.contains(session.id);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GlassCard(
        borderRadius: 20,
        borderColor: modeColor.withValues(alpha: 0.22),
        opacity: 0.08,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: modeColor.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: modeColor.withValues(alpha: 0.36),
                    ),
                  ),
                  child: Text(
                    session.modeLabel,
                    style: TextStyle(
                      color: modeColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.6,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.1),
                    ),
                  ),
                  child: Text(
                    session.profileLabel,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.72),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => _toggleFavorite(session),
                  icon: Icon(
                    session.isFavorite
                        ? Icons.star_rounded
                        : Icons.star_border_rounded,
                    color: session.isFavorite
                        ? const Color(0xFFFFC857)
                        : Colors.white.withValues(alpha: 0.36),
                    size: 20,
                  ),
                  splashRadius: 18,
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              _formatTimestamp(session.startedAt),
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.42),
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              session.summaryTitle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.94),
                fontSize: 18,
                fontWeight: FontWeight.w700,
                height: 1.3,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              session.summaryBody,
              maxLines: isExpanded ? 6 : 3,
              overflow: isExpanded
                  ? TextOverflow.visible
                  : TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.6),
                fontSize: 13,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildPreviewBlock(
                    label: tr('Transcript', '转录'),
                    icon: Icons.notes_rounded,
                    text: session.promptPreview,
                    accent: HelixTheme.cyan,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildPreviewBlock(
                    label: tr('AI Reply', 'AI 回复'),
                    icon: Icons.auto_awesome_outlined,
                    text: session.answerPreview,
                    accent: HelixTheme.purple,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildMetaChip(
                  Icons.forum_outlined,
                  '${session.turnCount} ${tr('turns', '轮')}',
                ),
                _buildMetaChip(
                  Icons.schedule_outlined,
                  _formatDuration(session.duration),
                ),
                _buildMetaChip(
                  Icons.bolt_outlined,
                  '${session.assistantCount} ${tr('AI replies', 'AI 回复')}',
                ),
                if (session.reviewSignalCount > 0)
                  _buildMetaChip(
                    Icons.description_outlined,
                    '${session.reviewSignalCount} ${tr('review signals', '审查信号')}',
                    accent: HelixTheme.purple,
                  ),
                if (session.hasActionItems)
                  _buildMetaChip(
                    Icons.task_alt_rounded,
                    '${session.actionItems.length} ${tr('action items', '待办事项')}',
                    accent: const Color(0xFF7CFFB2),
                  ),
                if (session.hasFactCheckFlags)
                  _buildMetaChip(
                    Icons.fact_check_outlined,
                    '${session.verificationCandidates.length} ${tr('fact-check flags', '事实核查')}',
                    accent: const Color(0xFFFFA726),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildActionButton(
                  icon: Icons.short_text_rounded,
                  label: tr('Copy summary', '复制摘要'),
                  onTap: () => _copyToClipboard(
                    '${session.summaryTitle}\n\n${session.summaryBody}',
                    tr('Session summary', '会话摘要'),
                  ),
                ),
                _buildActionButton(
                  icon: Icons.note_alt_outlined,
                  label: tr('Copy brief', '复制简报'),
                  onTap: session.reviewBrief.trim().isNotEmpty
                      ? () => _copyToClipboard(
                          session.reviewBrief,
                          tr('Review brief', '审查简报'),
                        )
                      : null,
                ),
                _buildActionButton(
                  icon: Icons.task_alt_rounded,
                  label: tr('Copy action items', '复制待办事项'),
                  onTap: session.hasActionItems
                      ? () => _copyToClipboard(
                          session.actionItems.join('\n'),
                          tr('Action items', '待办事项'),
                        )
                      : null,
                ),
                _buildActionButton(
                  icon: Icons.ios_share_rounded,
                  label: tr('Export text', '导出文本'),
                  onTap: () => _copyToClipboard(
                    session.fullTranscript,
                    tr('Session export', '会话导出'),
                  ),
                ),
                _buildActionButton(
                  icon: isExpanded
                      ? Icons.unfold_less_rounded
                      : Icons.unfold_more_rounded,
                  label: isExpanded
                      ? tr('Collapse', '收起')
                      : tr('Details', '详情'),
                  key: ValueKey('history-session-details-${session.id}'),
                  onTap: () => _toggleExpanded(session),
                ),
              ],
            ),
            if (isExpanded) ...[
              const SizedBox(height: 16),
              if (session.hasActionItems)
                _buildInsightBlock(
                  title: tr('Action Items', '待办事项'),
                  icon: Icons.task_alt_rounded,
                  accent: const Color(0xFF7CFFB2),
                  items: session.actionItems,
                ),
              if (session.hasActionItems && session.hasFactCheckFlags)
                const SizedBox(height: 12),
              if (session.hasFactCheckFlags)
                _buildInsightBlock(
                  title: tr('Verification Candidates', '待验证项'),
                  icon: Icons.fact_check_outlined,
                  accent: const Color(0xFFFFA726),
                  items: session.verificationCandidates,
                ),
              if (session.hasActionItems || session.hasFactCheckFlags)
                const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.08),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: session.timelineEntries
                      .map(
                        (entry) => _buildDetailRow(
                          entry,
                          session.timelineEntries.first.timestamp,
                        ),
                      )
                      .toList(),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPreviewBlock({
    required String label,
    required IconData icon,
    required String text,
    required Color accent,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: accent.withValues(alpha: 0.86)),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: accent.withValues(alpha: 0.86),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.6,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            text,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.76),
              fontSize: 12,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetaChip(IconData icon, String value, {Color? accent}) {
    final color = accent ?? Colors.white.withValues(alpha: 0.54);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            value,
            style: TextStyle(
              color: accent ?? Colors.white.withValues(alpha: 0.68),
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    Key? key,
    required IconData icon,
    required String label,
    required VoidCallback? onTap,
  }) {
    final isEnabled = onTap != null;
    return Material(
      key: key,
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: isEnabled ? 0.04 : 0.025),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: Colors.white.withValues(alpha: isEnabled ? 0.08 : 0.04),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 16,
                color: Colors.white.withValues(alpha: isEnabled ? 0.68 : 0.28),
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: Colors.white.withValues(
                    alpha: isEnabled ? 0.78 : 0.34,
                  ),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInsightBlock({
    required String title,
    required IconData icon,
    required Color accent,
    required List<String> items,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.035),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: accent),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  color: accent,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...items.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('•', style: TextStyle(color: accent, fontSize: 14)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      item,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.78),
                        fontSize: 12,
                        height: 1.45,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(SessionTimelineEntry entry, DateTime sessionStart) {
    final normalizedSpeaker = entry.speakerLabel.toLowerCase().trim();
    final isAssistant = entry.isAssistant;
    final accent = isAssistant
        ? HelixTheme.purple
        : normalizedSpeaker == 'other'
        ? HelixTheme.amber
        : HelixTheme.cyan;
    final label = switch (entry.displayLabel) {
      'You' => tr('You', '你'),
      'Other' => tr('Other', '对方'),
      'Conversation' => tr('Conversation', '对话'),
      _ => entry.displayLabel,
    };

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: accent.withValues(alpha: 0.14),
              border: Border.all(color: accent.withValues(alpha: 0.28)),
            ),
            child: Icon(
              isAssistant
                  ? Icons.auto_awesome
                  : normalizedSpeaker == 'other'
                  ? Icons.record_voice_over_outlined
                  : Icons.person_outline,
              size: 14,
              color: accent,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        color: accent,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      formatTranscriptElapsed(
                        entry.timestamp,
                        sessionStart: sessionStart,
                      ),
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.34),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  entry.text,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.78),
                    fontSize: 12,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildClearButton() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: SizedBox(
        width: double.infinity,
        child: GlassCard(
          borderRadius: 14,
          borderColor: Colors.redAccent.withValues(alpha: 0.26),
          opacity: 0.08,
          padding: EdgeInsets.zero,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: _clearHistory,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 15),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.delete_outline_rounded,
                      color: Colors.redAccent.withValues(alpha: 0.82),
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      tr('Clear History', '清除历史'),
                      style: TextStyle(
                        color: Colors.redAccent.withValues(alpha: 0.82),
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
