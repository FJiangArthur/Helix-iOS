// ABOUTME: Daily timeline view showing memories and conversation summaries.
// ABOUTME: Groups conversations by day with optional AI-generated daily narrative.

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/daily_memory.dart';
import '../services/daily_memory_service.dart';
import '../services/database/helix_database.dart';
import '../theme/helix_theme.dart';
import '../widgets/glass_card.dart';
import 'conversation_detail_screen.dart';

class MemoriesScreen extends StatefulWidget {
  const MemoriesScreen({super.key});

  @override
  State<MemoriesScreen> createState() => _MemoriesScreenState();
}

class _MemoriesScreenState extends State<MemoriesScreen> {
  List<_DaySection> _sections = [];
  Map<String, double> _costByConversationId = const {};
  bool _isLoading = true;
  bool _isRegenerating = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      final db = HelixDatabase.instance;

      // Load all conversations (most recent first)
      final allConversations = await db.conversationDao.getAllConversations(
        limit: 200,
      );
      final costByConversationId = await db.conversationDao
          .getAiCostTotalsForConversationIds(
            allConversations.map((conversation) => conversation.id).toList(),
          );

      // Load all daily memories
      final dailyMemories = await db.dailyMemoryDao.getRecentMemories(
        limit: 60,
      );

      // Build a map of date -> DailyMemoryModel
      final memoryByDate = <String, DailyMemoryModel>{};
      for (final dm in dailyMemories) {
        memoryByDate[dm.date] = DailyMemoryModel.fromDrift(dm);
      }

      // Group conversations by date
      final convsByDate = <String, List<Conversation>>{};
      for (final conv in allConversations) {
        final dt = DateTime.fromMillisecondsSinceEpoch(conv.startedAt);
        final dateStr = _formatDate(dt);
        convsByDate.putIfAbsent(dateStr, () => []).add(conv);
      }

      // Merge all dates (from conversations and memories)
      final allDates = <String>{...convsByDate.keys, ...memoryByDate.keys};
      final sortedDates = allDates.toList()..sort((a, b) => b.compareTo(a));

      final sections = <_DaySection>[];
      for (final dateStr in sortedDates) {
        sections.add(
          _DaySection(
            dateStr: dateStr,
            memory: memoryByDate[dateStr],
            conversations: convsByDate[dateStr] ?? [],
          ),
        );
      }

      setState(() {
        _sections = sections;
        _costByConversationId = costByConversationId;
        _isLoading = false;
      });
    } catch (_) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _onRefresh() async {
    setState(() => _isRegenerating = true);
    try {
      await DailyMemoryService.instance.generateDailyMemory();
    } catch (_) {}
    await _loadData();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HelixTheme.background,
      appBar: AppBar(
        title: const Text('Memories'),
        actions: [
          if (_isRegenerating)
            const Padding(
              padding: EdgeInsets.only(right: 16),
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
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: HelixTheme.cyan),
            )
          : _sections.isEmpty
          ? _buildEmptyState()
          : RefreshIndicator(
              onRefresh: _onRefresh,
              color: HelixTheme.cyan,
              backgroundColor: HelixTheme.surfaceRaised,
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                itemCount: _sections.length,
                itemBuilder: (context, index) =>
                    _buildDaySection(_sections[index]),
              ),
            ),
    );
  }

  Widget _buildEmptyState() {
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
              'No conversations yet',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'Your daily memories and conversation history will appear here after you start recording.',
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
          // Date header
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              _formatDateHeader(section.dateStr),
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(color: HelixTheme.cyan),
            ),
          ),

          // Daily memory narrative (if exists)
          if (section.memory != null) _buildMemoryCard(section.memory!),

          // Conversation cards
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
            // Header row
            Row(
              children: [
                const Icon(
                  Icons.auto_stories,
                  size: 16,
                  color: HelixTheme.purple,
                ),
                const SizedBox(width: 8),
                Text(
                  'Daily Memory',
                  style: Theme.of(
                    context,
                  ).textTheme.labelLarge?.copyWith(color: HelixTheme.purple),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Narrative
            Text(
              memory.narrative,
              style: Theme.of(context).textTheme.bodyLarge,
            ),

            // Theme tags
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
    final totalAiCostUsd = _costByConversationId[conv.id] ?? 0;

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
              builder: (_) => ConversationDetailScreen(conversationId: conv.id),
            ),
          );
        },
        child: GlassCard(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title row
              Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(
                        context,
                      ).textTheme.titleMedium?.copyWith(fontSize: 14),
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

              // Summary
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

              // Time + duration + sentiment
              Row(
                children: [
                  Text(timeStr, style: Theme.of(context).textTheme.bodySmall),
                  if (durationStr != null) ...[
                    const SizedBox(width: 8),
                    Text(
                      durationStr,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                  if (conv.sentiment != null && conv.sentiment!.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    _buildSentimentDot(conv.sentiment!),
                  ],
                  if (totalAiCostUsd > 0) ...[
                    const SizedBox(width: 8),
                    Text(
                      '\$${totalAiCostUsd.toStringAsFixed(4)}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: HelixTheme.cyan,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                  const Spacer(),
                  // Mode badge
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
      decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
    );
  }
}

/// Internal grouping for a single day's data.
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
