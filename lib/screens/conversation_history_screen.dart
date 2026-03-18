import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/assistant_session_meta.dart';
import '../services/conversation_engine.dart';
import '../services/settings_manager.dart';
import '../theme/helix_theme.dart';
import '../widgets/glass_card.dart';

class ConversationHistoryScreen extends StatefulWidget {
  const ConversationHistoryScreen({super.key});

  @override
  State<ConversationHistoryScreen> createState() =>
      _ConversationHistoryScreenState();
}

class _ConversationHistoryScreenState extends State<ConversationHistoryScreen> {
  static const List<String> _modeFilters = [
    'All',
    'General',
    'Interview',
    'Passive',
  ];
  static const List<String> _libraryFilters = [
    'All',
    'Favorites',
    'Action Items',
    'Fact-check Flags',
  ];
  static const String _favoriteKey = 'historyFavoriteSessionIds';

  List<ConversationTurn> _history = [];
  List<AssistantSessionMeta> _sessions = [];
  List<AssistantSessionMeta> _filteredSessions = [];
  final Set<String> _expandedSessionIds = <String>{};
  final Set<String> _favoriteSessionIds = <String>{};
  String _searchQuery = '';
  String _selectedMode = 'All';
  String _selectedLibraryFilter = 'All';
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _loadFavoritesAndHistory();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  Future<void> _loadFavoritesAndHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final favoriteIds = prefs.getStringList(_favoriteKey) ?? const <String>[];
    if (!mounted) return;
    setState(() {
      _favoriteSessionIds
        ..clear()
        ..addAll(favoriteIds);
      _history = ConversationEngine.instance.history;
      _sessions = _buildSessions(_history);
      _applyFilters();
    });
  }

  Future<void> _persistFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_favoriteKey, _favoriteSessionIds.toList());
  }

  void _loadHistory() {
    setState(() {
      _history = ConversationEngine.instance.history;
      _sessions = _buildSessions(_history);
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
        content: Text('$label copied'),
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
        title: const Text(
          'Clear History',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'Are you sure you want to clear all conversation history? This cannot be undone.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.white54),
            ),
          ),
          TextButton(
            onPressed: () {
              ConversationEngine.instance.clearHistory();
              _searchController.clear();
              _searchQuery = '';
              _selectedMode = 'All';
              _selectedLibraryFilter = 'All';
              _expandedSessionIds.clear();
              _loadHistory();
              Navigator.of(context).pop();
            },
            child: const Text(
              'Clear',
              style: TextStyle(color: Colors.redAccent),
            ),
          ),
        ],
      ),
    );
  }

  List<AssistantSessionMeta> _buildSessions(List<ConversationTurn> turns) {
    if (turns.isEmpty) return [];

    final sessions = <AssistantSessionMeta>[];
    var current = <ConversationTurn>[turns.first];
    final profiles = SettingsManager.instance.assistantProfiles;

    for (var i = 1; i < turns.length; i++) {
      final previous = turns[i - 1];
      final next = turns[i];
      if (_shouldStartNewSession(current, previous, next)) {
        final session = AssistantSessionMeta.fromTurns(
          current,
          profiles: profiles,
        );
        sessions.add(
          session.copyWith(
            isFavorite: _favoriteSessionIds.contains(session.id),
          ),
        );
        current = <ConversationTurn>[next];
      } else {
        current.add(next);
      }
    }

    final tail = AssistantSessionMeta.fromTurns(current, profiles: profiles);
    sessions.add(
      tail.copyWith(isFavorite: _favoriteSessionIds.contains(tail.id)),
    );
    return sessions.reversed.toList();
  }

  bool _shouldStartNewSession(
    List<ConversationTurn> currentSession,
    ConversationTurn previous,
    ConversationTurn next,
  ) {
    final gap = next.timestamp.difference(previous.timestamp);
    final currentMode = _modeLabel(currentSession.first.mode);
    final nextMode = _modeLabel(next.mode);

    if (currentMode != nextMode) return true;
    if (gap.inMinutes >= 25) return true;
    if (previous.role == 'assistant' &&
        next.role == 'user' &&
        gap.inMinutes >= 4) {
      return true;
    }
    return false;
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
    switch (mode?.toLowerCase()) {
      case 'interview':
        return HelixTheme.purple;
      case 'passive':
        return Colors.orangeAccent;
      case 'general':
      default:
        return HelixTheme.cyan;
    }
  }

  String _modeLabel(String? mode) {
    if (mode == null || mode.isEmpty) return 'General';
    return mode[0].toUpperCase() + mode.substring(1).toLowerCase();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HelixTheme.background,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            _buildSearchBar(),
            _buildModeFilterChips(),
            _buildLibraryFilterChips(),
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

  Widget _buildHeader() {
    final totalTurns = _history.length;
    final totalSessions = _sessions.length;
    final favoriteSessions = _sessions
        .where((session) => session.isFavorite)
        .length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: GlassCard(
        borderRadius: 20,
        borderColor: HelixTheme.cyan.withValues(alpha: 0.16),
        opacity: 0.08,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Session Library',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.96),
                fontSize: 22,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Browse previous conversations as reusable sessions instead of raw message bubbles.',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.58),
                fontSize: 13,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: _buildStatTile(
                    'Sessions',
                    '$totalSessions',
                    Icons.layers_outlined,
                    HelixTheme.cyan,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildStatTile(
                    'Turns',
                    '$totalTurns',
                    Icons.forum_outlined,
                    HelixTheme.purple,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildStatTile(
                    'Favorites',
                    '$favoriteSessions',
                    Icons.star_rounded,
                    const Color(0xFFFFC857),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatTile(
    String label,
    String value,
    IconData icon,
    Color color, {
    double valueFontSize = 18,
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
          Icon(icon, size: 16, color: color.withValues(alpha: 0.9)),
          const SizedBox(height: 12),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.48),
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.92),
              fontSize: valueFontSize,
              fontWeight: FontWeight.w600,
              height: 1.25,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
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
            hintText: 'Search sessions, prompts, answers, or action items',
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
    );
  }

  Widget _buildModeFilterChips() {
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _modeFilters.length,
        separatorBuilder: (_, index) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final mode = _modeFilters[index];
          final isSelected = _selectedMode == mode;
          final color = mode == 'All'
              ? HelixTheme.cyan
              : _modeColor(mode.toLowerCase());

          return GestureDetector(
            onTap: () => _onModeSelected(mode),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                mode,
                style: TextStyle(
                  color: isSelected
                      ? color
                      : Colors.white.withValues(alpha: 0.54),
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                  letterSpacing: 0.2,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildLibraryFilterChips() {
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
        itemCount: _libraryFilters.length,
        separatorBuilder: (_, index) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final filter = _libraryFilters[index];
          final isSelected = _selectedLibraryFilter == filter;
          final color = switch (filter) {
            'Favorites' => const Color(0xFFFFC857),
            'Action Items' => const Color(0xFF7CFFB2),
            'Fact-check Flags' => const Color(0xFFFFA726),
            _ => HelixTheme.cyan,
          };

          return GestureDetector(
            onTap: () => _onLibraryFilterSelected(filter),
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
                      : Colors.white.withValues(alpha: 0.1),
                ),
              ),
              child: Text(
                filter,
                style: TextStyle(
                  color: isSelected
                      ? color
                      : Colors.white.withValues(alpha: 0.54),
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
            ),
          );
        },
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
            const Text(
              'No Sessions Yet',
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Your assistant sessions will collect here as reusable conversation snapshots.',
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
                    'Start listening with the glasses connected.',
                  ),
                  const SizedBox(height: 12),
                  _buildSuggestionRow(
                    Icons.bolt_rounded,
                    'Use Quick Ask to generate a focused answer session.',
                  ),
                  const SizedBox(height: 12),
                  _buildSuggestionRow(
                    Icons.insights_outlined,
                    'Come back here to search and reuse past answers.',
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
            'No matching sessions',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.58),
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Try a different search term or library filter.',
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
                    label: 'Prompt',
                    icon: Icons.person_outline_rounded,
                    text: session.promptPreview,
                    accent: HelixTheme.cyan,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildPreviewBlock(
                    label: 'Answer',
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
                  '${session.turnCount} turns',
                ),
                _buildMetaChip(
                  Icons.schedule_outlined,
                  _formatDuration(session.duration),
                ),
                _buildMetaChip(
                  Icons.bolt_outlined,
                  '${session.assistantCount} AI replies',
                ),
                if (session.reviewSignalCount > 0)
                  _buildMetaChip(
                    Icons.description_outlined,
                    '${session.reviewSignalCount} review signals',
                    accent: HelixTheme.purple,
                  ),
                if (session.hasActionItems)
                  _buildMetaChip(
                    Icons.task_alt_rounded,
                    '${session.actionItems.length} action items',
                    accent: const Color(0xFF7CFFB2),
                  ),
                if (session.hasFactCheckFlags)
                  _buildMetaChip(
                    Icons.fact_check_outlined,
                    '${session.verificationCandidates.length} fact-check flags',
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
                  label: 'Copy summary',
                  onTap: () => _copyToClipboard(
                    '${session.summaryTitle}\n\n${session.summaryBody}',
                    'Session summary',
                  ),
                ),
                _buildActionButton(
                  icon: Icons.note_alt_outlined,
                  label: 'Copy brief',
                  onTap: session.reviewBrief.trim().isNotEmpty
                      ? () => _copyToClipboard(
                          session.reviewBrief,
                          'Review brief',
                        )
                      : null,
                ),
                _buildActionButton(
                  icon: Icons.task_alt_rounded,
                  label: 'Copy action items',
                  onTap: session.hasActionItems
                      ? () => _copyToClipboard(
                          session.actionItems.join('\n'),
                          'Action items',
                        )
                      : null,
                ),
                _buildActionButton(
                  icon: Icons.ios_share_rounded,
                  label: 'Export text',
                  onTap: () => _copyToClipboard(
                    session.fullTranscript,
                    'Session export',
                  ),
                ),
                _buildActionButton(
                  icon: isExpanded
                      ? Icons.unfold_less_rounded
                      : Icons.unfold_more_rounded,
                  label: isExpanded ? 'Collapse' : 'Details',
                  onTap: () => _toggleExpanded(session),
                ),
              ],
            ),
            if (isExpanded) ...[
              const SizedBox(height: 16),
              if (session.hasActionItems)
                _buildInsightBlock(
                  title: 'Action Items',
                  icon: Icons.task_alt_rounded,
                  accent: const Color(0xFF7CFFB2),
                  items: session.actionItems,
                ),
              if (session.hasActionItems && session.hasFactCheckFlags)
                const SizedBox(height: 12),
              if (session.hasFactCheckFlags)
                _buildInsightBlock(
                  title: 'Verification Candidates',
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
                  children: session.turns
                      .map((turn) => _buildDetailRow(turn))
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
    required IconData icon,
    required String label,
    required VoidCallback? onTap,
  }) {
    final isEnabled = onTap != null;
    return Material(
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

  Widget _buildDetailRow(ConversationTurn turn) {
    final isUser = turn.role == 'user';
    final accent = isUser ? HelixTheme.cyan : HelixTheme.purple;
    final label = isUser ? 'You' : 'Even AI';

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
              isUser ? Icons.person_outline : Icons.auto_awesome,
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
                      _formatTimestamp(turn.timestamp),
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.34),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  turn.content,
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
                      'Clear History',
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
