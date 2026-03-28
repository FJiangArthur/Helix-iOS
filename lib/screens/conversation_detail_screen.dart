// ABOUTME: Progressive-depth conversation viewer with Overview, Topics, and Transcript tabs.
// ABOUTME: Loads conversation data, segments, and topics from the drift database.

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/database/helix_database.dart';
import '../theme/helix_theme.dart';
import '../widgets/glass_card.dart';

class ConversationDetailScreen extends StatefulWidget {
  final String conversationId;

  const ConversationDetailScreen({
    super.key,
    required this.conversationId,
  });

  @override
  State<ConversationDetailScreen> createState() =>
      _ConversationDetailScreenState();
}

class _ConversationDetailScreenState extends State<ConversationDetailScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  Conversation? _conversation;
  List<ConversationSegment> _segments = [];
  List<Topic> _topics = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final db = HelixDatabase.instance;

    try {
      final conv =
          await db.conversationDao.watchConversation(widget.conversationId).first;
      final segments = await db.conversationDao
          .getSegmentsForConversation(widget.conversationId);
      final topics = await db.conversationDao
          .getTopicsForConversation(widget.conversationId);

      setState(() {
        _conversation = conv;
        _segments = segments;
        _topics = topics;
        _isLoading = false;
      });
    } catch (_) {
      setState(() => _isLoading = false);
    }
  }

  String get _title {
    if (_conversation?.title?.isNotEmpty == true) {
      return _conversation!.title!;
    }
    if (_segments.isNotEmpty) {
      final first = _segments.first.text_;
      return first.length > 50 ? '${first.substring(0, 50)}...' : first;
    }
    return 'Conversation';
  }

  String get _dateSubtitle {
    if (_conversation == null) return '';
    final dt = DateTime.fromMillisecondsSinceEpoch(_conversation!.startedAt);
    return DateFormat.yMMMd().add_jm().format(dt);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HelixTheme.background,
      appBar: AppBar(
        title: Column(
          children: [
            Text(
              _title,
              style: const TextStyle(fontSize: 16),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (!_isLoading)
              Text(
                _dateSubtitle,
                style: Theme.of(context).textTheme.bodySmall,
              ),
          ],
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: HelixTheme.cyan,
          labelColor: HelixTheme.cyan,
          unselectedLabelColor: HelixTheme.textMuted,
          labelStyle: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
          unselectedLabelStyle: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
          tabs: const [
            Tab(text: 'Overview'),
            Tab(text: 'Topics'),
            Tab(text: 'Transcript'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: HelixTheme.cyan),
            )
          : _conversation == null
              ? _buildNotFound()
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildOverviewTab(),
                    _buildTopicsTab(),
                    _buildTranscriptTab(),
                  ],
                ),
    );
  }

  Widget _buildNotFound() {
    return Center(
      child: Text(
        'Conversation not found',
        style: Theme.of(context).textTheme.bodyMedium,
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Overview Tab
  // ---------------------------------------------------------------------------

  Widget _buildOverviewTab() {
    final conv = _conversation!;
    final startTime = DateTime.fromMillisecondsSinceEpoch(conv.startedAt);

    String? durationStr;
    if (conv.endedAt != null) {
      final durationMs = conv.endedAt! - conv.startedAt;
      final minutes = (durationMs / 60000).round();
      durationStr = minutes < 1
          ? 'Less than a minute'
          : minutes < 60
              ? '$minutes minutes'
              : '${(minutes / 60).floor()}h ${minutes % 60}m';
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Summary card
        if (conv.summary != null && conv.summary!.isNotEmpty)
          GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.summarize, size: 16, color: HelixTheme.cyan),
                    const SizedBox(width: 8),
                    Text(
                      'Summary',
                      style: Theme.of(context)
                          .textTheme
                          .labelLarge
                          ?.copyWith(color: HelixTheme.cyan),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  conv.summary!,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ],
            ),
          ),

        const SizedBox(height: 12),

        // Metadata card
        GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildMetaRow('Mode', conv.mode),
              _buildMetaRow('Source', conv.source),
              _buildMetaRow('Started', DateFormat.jm().format(startTime)),
              if (durationStr != null) _buildMetaRow('Duration', durationStr),
              if (conv.sentiment != null && conv.sentiment!.isNotEmpty)
                _buildMetaRowWithWidget(
                  'Sentiment',
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildSentimentDot(conv.sentiment!),
                      const SizedBox(width: 8),
                      Text(
                        conv.sentiment!,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
              _buildMetaRow(
                'Segments',
                '${_segments.length}',
              ),
            ],
          ),
        ),

        // Topic pills
        if (_topics.isNotEmpty) ...[
          const SizedBox(height: 12),
          GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.tag, size: 16, color: HelixTheme.purple),
                    const SizedBox(width: 8),
                    Text(
                      'Topics',
                      style: Theme.of(context)
                          .textTheme
                          .labelLarge
                          ?.copyWith(color: HelixTheme.purple),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _topics.asMap().entries.map((entry) {
                    return _buildTopicPill(entry.value, entry.key);
                  }).toList(),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildMetaRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(
            width: 90,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetaRowWithWidget(String label, Widget child) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(
            width: 90,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          child,
        ],
      ),
    );
  }

  Widget _buildTopicPill(Topic topic, int index) {
    final colors = [
      HelixTheme.cyan,
      HelixTheme.purple,
      HelixTheme.lime,
      HelixTheme.amber,
    ];
    final color = colors[index % colors.length];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Text(
        topic.label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
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
      width: 10,
      height: 10,
      decoration: BoxDecoration(
        color: dotColor,
        shape: BoxShape.circle,
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Topics Tab
  // ---------------------------------------------------------------------------

  Widget _buildTopicsTab() {
    if (_topics.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 48),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.topic_outlined,
                size: 48,
                color: HelixTheme.textMuted.withValues(alpha: 0.4),
              ),
              const SizedBox(height: 12),
              Text(
                'No topics detected',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                'Topics will appear here once the conversation is processed by the AI pipeline.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _topics.length,
      itemBuilder: (context, index) {
        final topic = _topics[index];
        final topicSegments = _segments
            .where((s) => s.topicId == topic.id)
            .toList();

        return _TopicSection(
          topic: topic,
          segments: topicSegments,
          colorIndex: index,
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Transcript Tab
  // ---------------------------------------------------------------------------

  Widget _buildTranscriptTab() {
    if (_segments.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 48),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.mic_none,
                size: 48,
                color: HelixTheme.textMuted.withValues(alpha: 0.4),
              ),
              const SizedBox(height: 12),
              Text(
                'No transcript available',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _segments.length,
      itemBuilder: (context, index) {
        final seg = _segments[index];
        return _buildTranscriptBubble(seg);
      },
    );
  }

  Widget _buildTranscriptBubble(ConversationSegment seg) {
    final isMe = seg.speakerLabel?.toLowerCase() == 'me' ||
        seg.speakerLabel?.toLowerCase() == 'user' ||
        seg.speakerLabel == null;
    final speakerColor = isMe ? HelixTheme.cyan : HelixTheme.purple;
    final speakerLabel = isMe ? 'Me' : (seg.speakerLabel ?? 'Other');

    final time = DateTime.fromMillisecondsSinceEpoch(seg.startedAt);
    final timeStr = DateFormat.jms().format(time);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Speaker indicator
          Container(
            width: 4,
            height: 36,
            margin: const EdgeInsets.only(top: 4, right: 12),
            decoration: BoxDecoration(
              color: speakerColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Speaker + time
                Row(
                  children: [
                    Text(
                      speakerLabel,
                      style: TextStyle(
                        color: speakerColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      timeStr,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
                const SizedBox(height: 4),

                // Text
                Text(
                  seg.text_,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: HelixTheme.textPrimary,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Topic section widget (expandable)
// ---------------------------------------------------------------------------

class _TopicSection extends StatefulWidget {
  final Topic topic;
  final List<ConversationSegment> segments;
  final int colorIndex;

  const _TopicSection({
    required this.topic,
    required this.segments,
    required this.colorIndex,
  });

  @override
  State<_TopicSection> createState() => _TopicSectionState();
}

class _TopicSectionState extends State<_TopicSection> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final colors = [
      HelixTheme.cyan,
      HelixTheme.purple,
      HelixTheme.lime,
      HelixTheme.amber,
    ];
    final color = colors[widget.colorIndex % colors.length];

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GlassCard(
        borderColor: color.withValues(alpha: 0.2),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Topic header (tappable)
            GestureDetector(
              onTap: widget.segments.isNotEmpty
                  ? () => setState(() => _expanded = !_expanded)
                  : null,
              behavior: HitTestBehavior.opaque,
              child: Row(
                children: [
                  Container(
                    width: 4,
                    height: 20,
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      widget.topic.label,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: color,
                          ),
                    ),
                  ),
                  if (widget.segments.isNotEmpty)
                    Icon(
                      _expanded
                          ? Icons.keyboard_arrow_up
                          : Icons.keyboard_arrow_down,
                      color: HelixTheme.textMuted,
                      size: 20,
                    ),
                ],
              ),
            ),

            // Summary
            if (widget.topic.summary.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                widget.topic.summary,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],

            // Expanded segments
            if (_expanded && widget.segments.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 12),
              ...widget.segments.map((seg) {
                final isMe = seg.speakerLabel?.toLowerCase() == 'me' ||
                    seg.speakerLabel?.toLowerCase() == 'user' ||
                    seg.speakerLabel == null;
                final speakerColor =
                    isMe ? HelixTheme.cyan : HelixTheme.purple;
                final speaker = isMe ? 'Me' : (seg.speakerLabel ?? 'Other');

                return Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$speaker: ',
                        style: TextStyle(
                          color: speakerColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Expanded(
                        child: Text(
                          seg.text_,
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: HelixTheme.textPrimary,
                                  ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ],
        ),
      ),
    );
  }
}
