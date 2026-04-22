// ABOUTME: Tabbed screen merging Facts, Memories, and Ask Buzz into one page.
// ABOUTME: Uses DefaultTabController with three tabs for unified browsing.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/buzz_citation.dart';
import '../models/daily_memory.dart';
import '../models/fact.dart';
import '../services/buzz/buzz_service.dart';
import '../services/daily_memory_service.dart';
import '../services/database/helix_database.dart';
import '../services/facts/fact_service.dart';
import '../theme/helix_theme.dart';
import '../utils/i18n.dart';
import '../widgets/fact_card.dart';
import '../widgets/glass_card.dart';
import 'conversation_detail_screen.dart';
import 'settings_screen.dart';

// ---------------------------------------------------------------------------
// Chat message model (from BuzzScreen)
// ---------------------------------------------------------------------------

class _ChatMessage {
  final String role; // 'user' or 'assistant'
  final String? staticText;
  final Stream<String>? textStream;
  final List<BuzzCitation> citations;
  final bool isSearching;

  _ChatMessage({
    required this.role,
    this.staticText,
    this.textStream,
    this.citations = const [],
    this.isSearching = false,
  });
}

// ---------------------------------------------------------------------------
// Day section model (from MemoriesScreen)
// ---------------------------------------------------------------------------

class _DaySection {
  final String dateStr;
  final DailyMemoryModel? memory;
  final List<Conversation> conversations;

  const _DaySection({
    required this.dateStr,
    this.memory,
    required this.conversations,
  });
}

// ---------------------------------------------------------------------------
// InsightsScreen
// ---------------------------------------------------------------------------

class InsightsScreen extends StatefulWidget {
  const InsightsScreen({super.key});

  @override
  State<InsightsScreen> createState() => _InsightsScreenState();
}

class _InsightsScreenState extends State<InsightsScreen> {
  // ---- Facts state ----
  final _factService = FactService.instance;
  List<Fact> _pendingFacts = [];
  List<Fact> _confirmedFacts = [];
  int _confirmedCount = 0;
  String _searchQuery = '';
  final _searchController = TextEditingController();
  bool _searchExpanded = false;
  StreamSubscription<List<Fact>>? _pendingSub;
  StreamSubscription<List<Fact>>? _confirmedSub;
  final Set<String> _collapsedCategories = {};

  // ---- Memories state ----
  List<_DaySection> _sections = [];
  bool _isLoadingMemories = true;
  bool _isRegenerating = false;

  // ---- Buzz state ----
  final _buzzController = TextEditingController();
  final _scrollController = ScrollController();
  final _focusNode = FocusNode();
  final _messages = <_ChatMessage>[];
  bool _isProcessing = false;
  StreamSubscription<BuzzResponseEvent>? _activeSub;

  static final _starterChips = [
    tr('What topics came up this week?', '这周讨论了哪些话题？'),
    tr('Summarize my last conversation', '总结我的上一次对话'),
    tr('What do I know about...', '我了解到关于...'),
  ];

  // =========================================================================
  // Lifecycle
  // =========================================================================

  @override
  void initState() {
    super.initState();
    _initFacts();
    _loadMemories();
  }

  @override
  void dispose() {
    // Facts
    _pendingSub?.cancel();
    _confirmedSub?.cancel();
    _searchController.dispose();
    // Memories — nothing extra
    // Buzz
    _activeSub?.cancel();
    _buzzController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  // =========================================================================
  // Facts logic
  // =========================================================================

  void _initFacts() {
    _pendingSub = _factService.watchPendingFacts().listen((facts) {
      if (!mounted) return;
      setState(() => _pendingFacts = facts);
    });
    _confirmedSub = _factService.watchConfirmedFacts().listen((facts) {
      if (!mounted) return;
      setState(() {
        _confirmedFacts = facts;
        _confirmedCount = facts.length;
      });
    });
    _loadInitialFacts();
  }

  Future<void> _loadInitialFacts() async {
    final pending = await _factService.getPendingFacts();
    final confirmed = await _factService.getConfirmedFacts();
    final count = await _factService.getConfirmedCount();
    if (!mounted) return;
    setState(() {
      _pendingFacts = pending;
      _confirmedFacts = confirmed;
      _confirmedCount = count;
    });
  }

  Future<void> _confirmFact(Fact fact) async {
    await _factService.confirmFact(fact.id);
  }

  Future<void> _rejectFact(Fact fact) async {
    await _factService.rejectFact(fact.id);
  }

  Future<void> _onSearch(String query) async {
    _searchQuery = query;
    if (query.trim().isEmpty) {
      final confirmed = await _factService.getConfirmedFacts();
      if (!mounted) return;
      setState(() => _confirmedFacts = confirmed);
    } else {
      final results = await _factService.searchFacts(query);
      if (!mounted) return;
      setState(() => _confirmedFacts = results);
    }
  }

  // =========================================================================
  // Memories logic
  // =========================================================================

  Future<void> _loadMemories() async {
    setState(() => _isLoadingMemories = true);

    try {
      final db = HelixDatabase.instance;

      final allConversations = await db.conversationDao.getAllConversations(
        limit: 200,
      );

      final dailyMemories = await db.dailyMemoryDao.getRecentMemories(
        limit: 60,
      );

      final memoryByDate = <String, DailyMemoryModel>{};
      for (final dm in dailyMemories) {
        memoryByDate[dm.date] = DailyMemoryModel.fromDrift(dm);
      }

      final convsByDate = <String, List<Conversation>>{};
      for (final conv in allConversations) {
        final dt = DateTime.fromMillisecondsSinceEpoch(conv.startedAt);
        final dateStr = _formatDate(dt);
        convsByDate.putIfAbsent(dateStr, () => []).add(conv);
      }

      final allDates = <String>{...convsByDate.keys, ...memoryByDate.keys};
      final sortedDates = allDates.toList()..sort((a, b) => b.compareTo(a));

      final sections = <_DaySection>[];
      for (final dateStr in sortedDates) {
        sections.add(_DaySection(
          dateStr: dateStr,
          memory: memoryByDate[dateStr],
          conversations: convsByDate[dateStr] ?? [],
        ));
      }

      setState(() {
        _sections = sections;
        _isLoadingMemories = false;
      });
    } catch (_) {
      setState(() => _isLoadingMemories = false);
    }
  }

  Future<void> _onRefreshMemories() async {
    setState(() => _isRegenerating = true);
    try {
      await DailyMemoryService.instance.generateDailyMemory();
    } catch (_) {}
    await _loadMemories();
    setState(() => _isRegenerating = false);
  }

  String _formatDate(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  String _formatDateHeader(String dateStr) {
    final parts = dateStr.split('-');
    if (parts.length != 3) return dateStr;
    final date = DateTime(
      int.parse(parts[0]),
      int.parse(parts[1]),
      int.parse(parts[2]),
    );
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    if (date == today) return 'Today';
    if (date == yesterday) return 'Yesterday';
    return DateFormat.yMMMMd().format(date);
  }

  // =========================================================================
  // Buzz logic
  // =========================================================================

  void _sendBuzz(String text) {
    final question = text.trim();
    if (question.isEmpty || _isProcessing) return;

    _buzzController.clear();

    setState(() {
      _messages.add(_ChatMessage(role: 'user', staticText: question));
      _isProcessing = true;
    });
    _scrollToBottom();

    final streamController = StreamController<String>.broadcast();
    var fullText = '';
    var citations = <BuzzCitation>[];

    final assistantMsg = _ChatMessage(
      role: 'assistant',
      textStream: streamController.stream,
      isSearching: true,
    );
    setState(() => _messages.add(assistantMsg));

    _activeSub = BuzzService.instance.ask(question).listen(
      (event) {
        switch (event) {
          case BuzzSearching():
            break;
          case BuzzCitationsAvailable():
            final newCitations = event.citations;
            citations = newCitations;
            setState(() {
              final idx = _messages.indexOf(assistantMsg);
              if (idx >= 0) {
                _messages[idx] = _ChatMessage(
                  role: 'assistant',
                  textStream: streamController.stream,
                  citations: newCitations,
                );
              }
            });
          case BuzzTextDelta(:final text):
            fullText += text;
            streamController.add(text);
            _scrollToBottom();
          case BuzzComplete():
            streamController.close();
            setState(() {
              final idx = _messages.indexOf(assistantMsg);
              if (idx >= 0) {
                _messages[idx] = _ChatMessage(
                  role: 'assistant',
                  staticText: fullText,
                  citations: citations,
                );
              }
              _isProcessing = false;
            });
          case BuzzError(:final message):
            streamController.close();
            setState(() {
              final idx = _messages.indexOf(assistantMsg);
              if (idx >= 0) {
                _messages[idx] = _ChatMessage(
                  role: 'assistant',
                  staticText: 'Error: $message',
                );
              }
              _isProcessing = false;
            });
        }
      },
      onError: (Object e) {
        streamController.close();
        setState(() => _isProcessing = false);
      },
    );
  }

  void _clearBuzzHistory() {
    BuzzService.instance.clearHistory();
    setState(() => _messages.clear());
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // =========================================================================
  // Build
  // =========================================================================

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: HelixTheme.background,
        appBar: AppBar(
          title: Text(tr('Insights', '洞察')),
          backgroundColor: Colors.transparent,
          elevation: 0,
          actions: [
            IconButton(
              icon: const Icon(Icons.settings_outlined),
              tooltip: tr('Settings', '设置'),
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const SettingsScreen(),
                  ),
                );
              },
            ),
          ],
          bottom: TabBar(
            indicatorColor: HelixTheme.cyan,
            indicatorWeight: 2.5,
            labelColor: HelixTheme.textPrimary,
            unselectedLabelColor: HelixTheme.textMuted,
            labelStyle: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
            unselectedLabelStyle: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
            dividerColor: Colors.transparent,
            tabs: [
              Tab(text: tr('Facts', '事实')),
              Tab(text: tr('Memories', '记忆')),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildFactsTab(),
            _buildMemoriesTab(),
          ],
        ),
      ),
    );
  }

  // =========================================================================
  // Tab 1: Facts
  // =========================================================================

  Widget _buildFactsTab() {
    return Column(
      children: [
        // Search toggle row
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              IconButton(
                icon: Icon(
                  _searchExpanded ? Icons.close : Icons.search,
                  color: HelixTheme.textSecondary,
                ),
                onPressed: () {
                  setState(() {
                    _searchExpanded = !_searchExpanded;
                    if (!_searchExpanded) {
                      _searchController.clear();
                      _onSearch('');
                    }
                  });
                },
              ),
            ],
          ),
        ),
        Expanded(
          child: CustomScrollView(
            slivers: [
              // Search bar
              if (_searchExpanded)
                SliverToBoxAdapter(child: _buildSearchBar()),

              // Confirmed section header
              SliverToBoxAdapter(child: _buildConfirmedHeader()),

              // Confirmed grouped list
              if (_confirmedFacts.isEmpty)
                SliverToBoxAdapter(child: _buildEmptyConfirmed())
              else
                ..._buildCategoryGroups(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: TextField(
        controller: _searchController,
        autofocus: true,
        style: const TextStyle(color: HelixTheme.textPrimary, fontSize: 14),
        decoration: InputDecoration(
          hintText: tr('Search facts...', '搜索事实...'),
          prefixIcon:
              const Icon(Icons.search, color: HelixTheme.textMuted, size: 20),
        ),
        onChanged: _onSearch,
      ),
    );
  }

  // ignore: unused_element
  Widget _buildPendingHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
      child: Text(
        '${_pendingFacts.length} new fact${_pendingFacts.length == 1 ? '' : 's'} to review',
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: HelixTheme.textSecondary,
            ),
      ),
    );
  }

  // ignore: unused_element
  Widget _buildPendingCards() {
    final fact = _pendingFacts.first;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: SizedBox(
        height: 220,
        child: Stack(
          children: [
            if (_pendingFacts.length > 2)
              Positioned(
                top: 12,
                left: 12,
                right: 12,
                child: _buildGhostCard(opacity: 0.08),
              ),
            if (_pendingFacts.length > 1)
              Positioned(
                top: 6,
                left: 6,
                right: 6,
                child: _buildGhostCard(opacity: 0.14),
              ),
            Dismissible(
              key: ValueKey(fact.id),
              direction: DismissDirection.horizontal,
              onDismissed: (direction) {
                if (direction == DismissDirection.startToEnd) {
                  _confirmFact(fact);
                } else {
                  _rejectFact(fact);
                }
              },
              background: _buildSwipeBackground(
                alignment: Alignment.centerLeft,
                color: HelixTheme.lime,
                icon: Icons.check_rounded,
                label: tr('Confirm', '确认'),
              ),
              secondaryBackground: _buildSwipeBackground(
                alignment: Alignment.centerRight,
                color: HelixTheme.error,
                icon: Icons.close_rounded,
                label: tr('Reject', '拒绝'),
              ),
              child: SizedBox(
                width: double.infinity,
                child: FactCard(
                  category: fact.category,
                  content: fact.content,
                  sourceQuote: fact.sourceQuote,
                  confidence: fact.confidence,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGhostCard({required double opacity}) {
    return GlassCard(
      opacity: opacity,
      padding: const EdgeInsets.all(20),
      child: const SizedBox(height: 140),
    );
  }

  Widget _buildSwipeBackground({
    required Alignment alignment,
    required Color color,
    required IconData icon,
    required String label,
  }) {
    return Container(
      alignment: alignment,
      padding: const EdgeInsets.symmetric(horizontal: 28),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  // ignore: unused_element
  Widget _buildAllCaughtUp() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
      child: GlassCard(
        opacity: 0.10,
        padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
        child: Center(
          child: Column(
            children: [
              Icon(
                Icons.check_circle_outline_rounded,
                color: HelixTheme.lime.withValues(alpha: 0.6),
                size: 36,
              ),
              const SizedBox(height: 12),
              Text(
                tr('All caught up!', '已全部查看！'),
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: HelixTheme.textSecondary,
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                tr('New facts will appear here after conversations.', '对话后新发现的事实将出现在这里。'),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildConfirmedHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
      child: Row(
        children: [
          Text(
            tr('Knowledge Graph', '知识图谱'),
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const Spacer(),
          Text(
            '$_confirmedCount confirmed',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyConfirmed() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Center(
        child: Text(
          _searchQuery.isNotEmpty
              ? 'No facts match "$_searchQuery"'
              : tr('Confirmed facts will appear here.', '已确认的事实将显示在这里。'),
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ),
    );
  }

  List<Widget> _buildCategoryGroups() {
    final grouped = <String, List<Fact>>{};
    for (final fact in _confirmedFacts) {
      grouped.putIfAbsent(fact.category, () => []).add(fact);
    }

    final sortedKeys = grouped.keys.toList()..sort();

    return sortedKeys.map((category) {
      final facts = grouped[category]!;
      final color = FactCard.categoryColor(category);
      final catEnum = FactCategory.fromString(category);
      final isCollapsed = _collapsedCategories.contains(category);

      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () {
                  setState(() {
                    if (isCollapsed) {
                      _collapsedCategories.remove(category);
                    } else {
                      _collapsedCategories.add(category);
                    }
                  });
                },
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
                  child: Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        catEnum.displayName,
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  color: color,
                                ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '(${facts.length})',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const Spacer(),
                      Icon(
                        isCollapsed
                            ? Icons.expand_more_rounded
                            : Icons.expand_less_rounded,
                        color: HelixTheme.textMuted,
                        size: 20,
                      ),
                    ],
                  ),
                ),
              ),
              if (!isCollapsed)
                ...facts.map((fact) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: GlassCard(
                        opacity: 0.10,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              fact.content,
                              style: Theme.of(context).textTheme.bodyLarge,
                            ),
                            if (fact.sourceQuote != null &&
                                fact.sourceQuote!.isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Text(
                                fact.sourceQuote!,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(fontStyle: FontStyle.italic),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ],
                        ),
                      ),
                    )),
            ],
          ),
        ),
      );
    }).toList();
  }

  // =========================================================================
  // Tab 2: Memories
  // =========================================================================

  Widget _buildMemoriesTab() {
    if (_isLoadingMemories) {
      return const Center(
        child: CircularProgressIndicator(color: HelixTheme.cyan),
      );
    }

    if (_sections.isEmpty) {
      return _buildMemoriesEmptyState();
    }

    return Stack(
      children: [
        RefreshIndicator(
          onRefresh: _onRefreshMemories,
          color: HelixTheme.cyan,
          backgroundColor: HelixTheme.surfaceRaised,
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            itemCount: _sections.length,
            itemBuilder: (context, index) =>
                _buildDaySection(_sections[index]),
          ),
        ),
        if (_isRegenerating)
          Positioned(
            top: 8,
            right: 16,
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: HelixTheme.cyan,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildMemoriesEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 48),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.auto_stories_outlined,
              size: 64,
              color: HelixTheme.textMuted.withValues(alpha: 0.4),
            ),
            const SizedBox(height: 16),
            Text(
              tr('No conversations yet', '暂无对话'),
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              tr('Your daily memories and conversation history will appear here after you start recording.', '开始录音后，你的每日记忆和对话历史将显示在这里。'),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDaySection(_DaySection section) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              _formatDateHeader(section.dateStr),
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: HelixTheme.cyan,
                  ),
            ),
          ),
          if (section.memory != null) _buildMemoryCard(section.memory!),
          ...section.conversations.map(_buildConversationCard),
        ],
      ),
    );
  }

  Widget _buildMemoryCard(DailyMemoryModel memory) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GlassCard(
        borderColor: HelixTheme.purple.withValues(alpha: 0.3),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.auto_stories,
                  size: 16,
                  color: HelixTheme.purple,
                ),
                const SizedBox(width: 8),
                Text(
                  tr('Daily Memory', '每日记忆'),
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: HelixTheme.purple,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              memory.narrative,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            if (memory.themes.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: memory.themes.asMap().entries.map((entry) {
                  return _buildThemeChip(entry.value, entry.key);
                }).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildThemeChip(String theme, int index) {
    final colors = [
      HelixTheme.cyan,
      HelixTheme.purple,
      HelixTheme.lime,
      HelixTheme.amber,
      HelixTheme.error,
    ];
    final color = colors[index % colors.length];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Text(
        theme,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildConversationCard(Conversation conv) {
    final startTime = DateTime.fromMillisecondsSinceEpoch(conv.startedAt);
    final timeStr = DateFormat.jm().format(startTime);

    String? durationStr;
    if (conv.endedAt != null) {
      final durationMs = conv.endedAt! - conv.startedAt;
      final minutes = (durationMs / 60000).round();
      durationStr = minutes < 1
          ? '<1 min'
          : minutes < 60
              ? '$minutes min'
              : '${(minutes / 60).floor()}h ${minutes % 60}m';
    }

    final title = conv.title?.isNotEmpty == true
        ? conv.title!
        : conv.summary?.isNotEmpty == true
            ? conv.summary!
            : 'Untitled conversation';

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GestureDetector(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) =>
                  ConversationDetailScreen(conversationId: conv.id),
            ),
          );
        },
        child: GlassCard(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontSize: 14,
                          ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    Icons.chevron_right,
                    size: 18,
                    color: HelixTheme.textMuted.withValues(alpha: 0.6),
                  ),
                ],
              ),
              if (conv.summary != null && conv.summary!.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  conv.summary!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
              const SizedBox(height: 8),
              Row(
                children: [
                  Text(
                    timeStr,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  if (durationStr != null) ...[
                    const SizedBox(width: 8),
                    Text(
                      durationStr,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                  if (conv.sentiment != null &&
                      conv.sentiment!.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    _buildSentimentDot(conv.sentiment!),
                  ],
                  const Spacer(),
                  if (conv.mode != 'general')
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: HelixTheme.surfaceInteractive,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        conv.mode,
                        style: const TextStyle(
                          color: HelixTheme.textMuted,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSentimentDot(String sentiment) {
    final lower = sentiment.toLowerCase();
    Color dotColor;
    if (lower.contains('positive') || lower.contains('happy')) {
      dotColor = HelixTheme.lime;
    } else if (lower.contains('negative') ||
        lower.contains('sad') ||
        lower.contains('angry')) {
      dotColor = HelixTheme.error;
    } else {
      dotColor = HelixTheme.amber;
    }

    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        color: dotColor,
        shape: BoxShape.circle,
      ),
    );
  }

  // =========================================================================
  // Tab 3: Ask Buzz
  // =========================================================================

  // ignore: unused_element
  Widget _buildBuzzTab() {
    return SafeArea(
      top: false,
      child: Column(
        children: [
          // Clear history button
          if (_messages.isNotEmpty)
            Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.only(right: 8, top: 4),
                child: IconButton(
                  icon: const Icon(Icons.delete_outline,
                      color: HelixTheme.textMuted),
                  tooltip: tr('Clear history', '清除历史'),
                  onPressed: _clearBuzzHistory,
                ),
              ),
            ),
          Expanded(
            child: _messages.isEmpty ? _buildBuzzStarters() : _buildChatList(),
          ),
          _buildBuzzInputBar(),
        ],
      ),
    );
  }

  Widget _buildBuzzStarters() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.auto_awesome,
                size: 48, color: HelixTheme.cyan.withValues(alpha: 0.6)),
            const SizedBox(height: 16),
            Text(
              tr('Ask Buzz anything about your conversations', '向 Buzz 询问关于你对话的任何问题'),
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: HelixTheme.textSecondary,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: _starterChips.map((chip) {
                return ActionChip(
                  label: Text(chip,
                      style: const TextStyle(
                          color: HelixTheme.cyan, fontSize: 13)),
                  backgroundColor: Colors.transparent,
                  side: const BorderSide(color: HelixTheme.cyan),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  onPressed: () => _sendBuzz(chip),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChatList() {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: _messages.length,
      itemBuilder: (context, index) {
        final msg = _messages[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: msg.role == 'user'
              ? _buildUserBubble(msg)
              : _buildAssistantBubble(msg),
        );
      },
    );
  }

  Widget _buildUserBubble(_ChatMessage msg) {
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: HelixTheme.surfaceInteractive,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          msg.staticText ?? '',
          style: const TextStyle(color: HelixTheme.textPrimary, fontSize: 15),
        ),
      ),
    );
  }

  Widget _buildAssistantBubble(_ChatMessage msg) {
    return Align(
      alignment: Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.85,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GlassCard(
              padding: const EdgeInsets.all(14),
              child: msg.isSearching
                  ? _buildSearchingIndicator()
                  : _buildAssistantText(msg),
            ),
            if (msg.citations.isNotEmpty) ...[
              const SizedBox(height: 6),
              _buildCitationChips(msg.citations),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSearchingIndicator() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: HelixTheme.cyan.withValues(alpha: 0.7),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          tr('Searching your conversations...', '搜索对话中...'),
          style: TextStyle(
            color: HelixTheme.textSecondary,
            fontSize: 14,
            fontStyle: FontStyle.italic,
          ),
        ),
      ],
    );
  }

  Widget _buildAssistantText(_ChatMessage msg) {
    if (msg.staticText != null) {
      return SelectableText(
        msg.staticText!,
        style: Theme.of(context).textTheme.bodyLarge,
      );
    }

    return _StreamingText(stream: msg.textStream!);
  }

  Widget _buildCitationChips(List<BuzzCitation> citations) {
    return Wrap(
      spacing: 6,
      runSpacing: 4,
      children: citations.take(5).map((c) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: HelixTheme.purple.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(12),
            border:
                Border.all(color: HelixTheme.purple.withValues(alpha: 0.3)),
          ),
          child: Text(
            c.label,
            style: const TextStyle(
              color: HelixTheme.purple,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildBuzzInputBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 8, 12),
      decoration: BoxDecoration(
        color: HelixTheme.backgroundRaised,
        border: Border(
          top: BorderSide(
              color: HelixTheme.borderSubtle.withValues(alpha: 0.5)),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _buzzController,
              focusNode: _focusNode,
              style: const TextStyle(
                  color: HelixTheme.textPrimary, fontSize: 15),
              decoration: InputDecoration(
                hintText: tr('Ask Buzz a question...', '向 Buzz 提问...'),
                filled: true,
                fillColor: HelixTheme.surfaceInteractive,
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide:
                      const BorderSide(color: HelixTheme.borderSubtle),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: const BorderSide(color: HelixTheme.cyan),
                ),
              ),
              textInputAction: TextInputAction.send,
              onSubmitted: _sendBuzz,
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: Icon(
              Icons.send_rounded,
              color:
                  _isProcessing ? HelixTheme.textMuted : HelixTheme.cyan,
            ),
            onPressed:
                _isProcessing ? null : () => _sendBuzz(_buzzController.text),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Streaming text widget (from BuzzScreen)
// ---------------------------------------------------------------------------

class _StreamingText extends StatefulWidget {
  final Stream<String> stream;
  const _StreamingText({required this.stream});

  @override
  State<_StreamingText> createState() => _StreamingTextState();
}

class _StreamingTextState extends State<_StreamingText> {
  String _text = '';
  StreamSubscription<String>? _sub;

  @override
  void initState() {
    super.initState();
    _sub = widget.stream.listen((chunk) {
      if (mounted) setState(() => _text += chunk);
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_text.isEmpty) {
      return SizedBox(
        height: 20,
        child: Center(
          child: SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: HelixTheme.cyan.withValues(alpha: 0.5),
            ),
          ),
        ),
      );
    }
    return SelectableText(
      _text,
      style: Theme.of(context).textTheme.bodyLarge,
    );
  }
}
