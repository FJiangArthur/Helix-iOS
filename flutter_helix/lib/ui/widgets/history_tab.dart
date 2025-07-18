// ABOUTME: Enhanced history tab with search, filtering, and export capabilities
// ABOUTME: Comprehensive conversation history management with analytics and insights

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:async';

import '../../services/conversation_storage_service.dart';
import '../../services/service_locator.dart';
import '../../models/conversation_model.dart';

class HistoryTab extends StatefulWidget {
  const HistoryTab({super.key});

  @override
  State<HistoryTab> createState() => _HistoryTabState();
}

class _HistoryTabState extends State<HistoryTab> with TickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  
  String _searchQuery = '';
  ConversationFilter _currentFilter = ConversationFilter.all;
  ConversationSort _currentSort = ConversationSort.newest;
  bool _isSearching = false;
  
  // Storage service integration
  late ConversationStorageService _storageService;
  StreamSubscription<List<ConversationModel>>? _conversationSubscription;
  List<ConversationModel> _conversations = [];
  
  final List<ConversationHistory> _mockConversations = [
    ConversationHistory(
      id: 'conv_001',
      title: 'Team Meeting Discussion',
      date: DateTime.now().subtract(const Duration(hours: 2)),
      duration: const Duration(minutes: 45),
      participantCount: 4,
      transcriptLength: 2847,
      summary: 'Discussion about Q4 planning, budget allocation, and upcoming product launches.',
      tags: ['meeting', 'planning', 'business'],
      sentiment: SentimentType.positive,
      hasFactChecks: true,
      hasActionItems: true,
      isStarred: true,
    ),
    ConversationHistory(
      id: 'conv_002',
      title: 'Technical Architecture Review',
      date: DateTime.now().subtract(const Duration(days: 1)),
      duration: const Duration(minutes: 67),
      participantCount: 3,
      transcriptLength: 4192,
      summary: 'Deep dive into system architecture, performance optimization, and scalability concerns.',
      tags: ['technical', 'architecture', 'performance'],
      sentiment: SentimentType.neutral,
      hasFactChecks: true,
      hasActionItems: false,
      isStarred: false,
    ),
    ConversationHistory(
      id: 'conv_003',
      title: 'Client Feedback Session',
      date: DateTime.now().subtract(const Duration(days: 3)),
      duration: const Duration(minutes: 32),
      participantCount: 2,
      transcriptLength: 1654,
      summary: 'Client expressed concerns about delivery timeline and feature completeness.',
      tags: ['client', 'feedback', 'concerns'],
      sentiment: SentimentType.negative,
      hasFactChecks: false,
      hasActionItems: true,
      isStarred: false,
    ),
    ConversationHistory(
      id: 'conv_004',
      title: 'Innovation Brainstorm',
      date: DateTime.now().subtract(const Duration(days: 5)),
      duration: const Duration(minutes: 89),
      participantCount: 6,
      transcriptLength: 5234,
      summary: 'Creative session exploring new features, market opportunities, and technology trends.',
      tags: ['innovation', 'brainstorm', 'creative'],
      sentiment: SentimentType.positive,
      hasFactChecks: false,
      hasActionItems: true,
      isStarred: true,
    ),
  ];
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _searchController.addListener(_onSearchChanged);
    _initializeStorageService();
  }
  
  Future<void> _initializeStorageService() async {
    try {
      _storageService = ServiceLocator.instance.get<ConversationStorageService>();
      
      // Load existing conversations
      final conversations = await _storageService.getAllConversations();
      setState(() {
        _conversations = conversations;
      });
      
      // Listen for conversation updates
      _conversationSubscription = _storageService.conversationStream.listen((conversations) {
        if (mounted) {
          setState(() {
            _conversations = conversations;
          });
        }
      });
    } catch (e) {
      debugPrint('Failed to initialize storage service: $e');
    }
  }
  
  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    _conversationSubscription?.cancel();
    super.dispose();
  }
  
  void _onSearchChanged() {
    setState(() {
      _searchQuery = _searchController.text;
    });
  }
  
  List<ConversationModel> get _filteredConversations {
    var filtered = _conversations.where((conv) {
      // Search filter
      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        if (!conv.title.toLowerCase().contains(query)) {
          // Also search in conversation segments
          final hasMatchingSegment = conv.segments.any((segment) =>
              segment.text.toLowerCase().contains(query));
          if (!hasMatchingSegment) {
            return false;
          }
        }
      }
      
      // Category filter
      switch (_currentFilter) {
        case ConversationFilter.starred:
          return conv.isPinned; // Use isPinned as starred
        case ConversationFilter.withFactChecks:
          return conv.hasAIAnalysis; // Use hasAIAnalysis as fact checks
        case ConversationFilter.withActions:
          return false; // No action items in ConversationModel yet
        case ConversationFilter.thisWeek:
          return conv.startTime.isAfter(DateTime.now().subtract(const Duration(days: 7)));
        case ConversationFilter.all:
        default:
          return true;
      }
    }).toList();
    
    // Sort
    switch (_currentSort) {
      case ConversationSort.newest:
        filtered.sort((a, b) => b.startTime.compareTo(a.startTime));
        break;
      case ConversationSort.oldest:
        filtered.sort((a, b) => a.startTime.compareTo(b.startTime));
        break;
      case ConversationSort.longest:
        filtered.sort((a, b) => b.duration.compareTo(a.duration));
        break;
      case ConversationSort.mostParticipants:
        filtered.sort((a, b) => b.participants.length.compareTo(a.participants.length));
        break;
    }
    
    return filtered;
  }
  
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      appBar: AppBar(
        title: _isSearching 
          ? TextField(
              controller: _searchController,
              autofocus: true,
              decoration: const InputDecoration(
                hintText: 'Search conversations...',
                border: InputBorder.none,
              ),
              style: theme.textTheme.titleLarge,
            )
          : const Text('Conversation History'),
        backgroundColor: theme.colorScheme.surface,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(_isSearching ? Icons.close : Icons.search),
            onPressed: () {
              setState(() {
                _isSearching = !_isSearching;
                if (!_isSearching) {
                  _searchController.clear();
                }
              });
            },
          ),
          if (!_isSearching)
            PopupMenuButton<String>(
              onSelected: (value) {
                switch (value) {
                  case 'export_all':
                    _showExportDialog(context);
                    break;
                  case 'analytics':
                    _showAnalyticsDialog(context);
                    break;
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'export_all',
                  child: Row(
                    children: [
                      Icon(Icons.download),
                      SizedBox(width: 8),
                      Text('Export All'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'analytics',
                  child: Row(
                    children: [
                      Icon(Icons.analytics),
                      SizedBox(width: 8),
                      Text('View Analytics'),
                    ],
                  ),
                ),
              ],
            ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.list), text: 'Conversations'),
            Tab(icon: Icon(Icons.insights), text: 'Insights'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildConversationsTab(theme),
          _buildInsightsTab(theme),
        ],
      ),
    );
  }
  
  Widget _buildConversationsTab(ThemeData theme) {
    return Column(
      children: [
        // Filter and Sort Controls
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            border: Border(
              bottom: BorderSide(
                color: theme.colorScheme.outline.withOpacity(0.2),
              ),
            ),
          ),
          child: Row(
            children: [
              // Filter
              Expanded(
                child: DropdownButtonFormField<ConversationFilter>(
                  value: _currentFilter,
                  decoration: const InputDecoration(
                    labelText: 'Filter',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  items: ConversationFilter.values.map((filter) {
                    return DropdownMenuItem(
                      value: filter,
                      child: Text(_getFilterLabel(filter)),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      _currentFilter = value!;
                    });
                  },
                ),
              ),
              const SizedBox(width: 12),
              // Sort
              Expanded(
                child: DropdownButtonFormField<ConversationSort>(
                  value: _currentSort,
                  decoration: const InputDecoration(
                    labelText: 'Sort By',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  items: ConversationSort.values.map((sort) {
                    return DropdownMenuItem(
                      value: sort,
                      child: Text(_getSortLabel(sort)),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      _currentSort = value!;
                    });
                  },
                ),
              ),
            ],
          ),
        ),
        
        // Conversations List
        Expanded(
          child: _filteredConversations.isEmpty
            ? _buildEmptyState(theme)
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _filteredConversations.length,
                itemBuilder: (context, index) {
                  final conversation = _filteredConversations[index];
                  return ConversationCard(
                    conversation: conversation,
                    onTap: () => _openConversationDetail(conversation),
                    onStar: () => _toggleStar(conversation),
                    onShare: () => _shareConversation(conversation),
                    onDelete: () => _deleteConversation(conversation),
                  );
                },
              ),
        ),
      ],
    );
  }
  
  Widget _buildInsightsTab(ThemeData theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStatsCards(theme),
          const SizedBox(height: 16),
          _buildTrendChart(theme),
          const SizedBox(height: 16),
          _buildTopicsCard(theme),
          const SizedBox(height: 16),
          _buildSentimentCard(theme),
        ],
      ),
    );
  }
  
  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            _searchQuery.isNotEmpty ? Icons.search_off : Icons.history,
            size: 64,
            color: theme.colorScheme.outline,
          ),
          const SizedBox(height: 24),
          Text(
            _searchQuery.isNotEmpty ? 'No Results Found' : 'No Conversations Yet',
            style: theme.textTheme.headlineSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _searchQuery.isNotEmpty 
              ? 'Try adjusting your search terms or filters'
              : 'Start a conversation to see it here',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          if (_searchQuery.isNotEmpty) ...[
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                _searchController.clear();
                setState(() {
                  _currentFilter = ConversationFilter.all;
                });
              },
              child: const Text('Clear Search'),
            ),
          ],
        ],
      ),
    );
  }
  
  Widget _buildStatsCards(ThemeData theme) {
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            theme,
            'Total Conversations',
            '${_conversations.length}',
            Icons.chat_bubble_outline,
            theme.colorScheme.primary,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            theme,
            'Total Duration',
            _formatTotalDuration(),
            Icons.schedule,
            Colors.green,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            theme,
            'Avg Participants',
            _getAverageParticipants(),
            Icons.group,
            Colors.orange,
          ),
        ),
      ],
    );
  }
  
  Widget _buildStatCard(ThemeData theme, String label, String value, IconData icon, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 8),
            Text(
              value,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              label,
              style: theme.textTheme.labelSmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildTrendChart(ThemeData theme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.trending_up, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'Activity Trend',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 100,
              child: Center(
                child: Text(
                  'Trend visualization would go here',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildTopicsCard(ThemeData theme) {
    final allTags = <String>{};
    for (final conv in _conversations) {
      allTags.addAll(conv.tags);
    }
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.tag, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'Popular Topics',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: allTags.map((tag) => Chip(
                label: Text(tag),
                backgroundColor: theme.colorScheme.secondaryContainer,
              )).toList(),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildSentimentCard(ThemeData theme) {
    final sentimentCounts = <SentimentType, int>{};
    for (final conv in _conversations) {
      // Default to neutral sentiment for ConversationModel since it doesn't have sentiment
      sentimentCounts[SentimentType.neutral] = (sentimentCounts[SentimentType.neutral] ?? 0) + 1;
    }
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.sentiment_satisfied, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'Sentiment Distribution',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...sentimentCounts.entries.map((entry) {
              final percentage = (entry.value / _conversations.length * 100).round();
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Icon(
                      _getSentimentIcon(entry.key),
                      color: _getSentimentColor(entry.key),
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        entry.key.name.toUpperCase(),
                        style: theme.textTheme.labelMedium,
                      ),
                    ),
                    Text(
                      '$percentage%',
                      style: theme.textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
  
  String _getFilterLabel(ConversationFilter filter) {
    switch (filter) {
      case ConversationFilter.all:
        return 'All Conversations';
      case ConversationFilter.starred:
        return 'Starred';
      case ConversationFilter.withFactChecks:
        return 'With Fact Checks';
      case ConversationFilter.withActions:
        return 'With Action Items';
      case ConversationFilter.thisWeek:
        return 'This Week';
    }
  }
  
  String _getSortLabel(ConversationSort sort) {
    switch (sort) {
      case ConversationSort.newest:
        return 'Newest First';
      case ConversationSort.oldest:
        return 'Oldest First';
      case ConversationSort.longest:
        return 'Longest First';
      case ConversationSort.mostParticipants:
        return 'Most Participants';
    }
  }
  
  String _formatTotalDuration() {
    final totalMinutes = _conversations.fold<int>(
      0, (sum, conv) => sum + conv.duration.inMinutes,
    );
    final hours = totalMinutes ~/ 60;
    final minutes = totalMinutes % 60;
    return '${hours}h ${minutes}m';
  }
  
  String _getAverageParticipants() {
    if (_conversations.isEmpty) return '0';
    final avg = _conversations.fold<int>(
      0, (sum, conv) => sum + conv.participants.length,
    ) / _conversations.length;
    return avg.toStringAsFixed(1);
  }
  
  IconData _getSentimentIcon(SentimentType sentiment) {
    switch (sentiment) {
      case SentimentType.positive:
        return Icons.sentiment_very_satisfied;
      case SentimentType.negative:
        return Icons.sentiment_very_dissatisfied;
      case SentimentType.neutral:
        return Icons.sentiment_neutral;
      case SentimentType.mixed:
        return Icons.sentiment_satisfied;
    }
  }
  
  Color _getSentimentColor(SentimentType sentiment) {
    switch (sentiment) {
      case SentimentType.positive:
        return Colors.green;
      case SentimentType.negative:
        return Colors.red;
      case SentimentType.neutral:
        return Colors.grey;
      case SentimentType.mixed:
        return Colors.orange;
    }
  }
  
  void _openConversationDetail(ConversationModel conversation) {
    // TODO: Navigate to conversation detail page
  }
  
  void _toggleStar(ConversationModel conversation) async {
    try {
      final updatedConversation = conversation.copyWith(isPinned: !conversation.isPinned);
      await _storageService.saveConversation(updatedConversation);
      // The conversation stream will automatically update the UI
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update conversation: $e')),
        );
      }
    }
  }
  
  void _shareConversation(ConversationModel conversation) {
    // TODO: Implement share functionality
  }
  
  void _deleteConversation(ConversationModel conversation) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Conversation'),
        content: Text('Are you sure you want to delete "${conversation.title}"? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                await _storageService.deleteConversation(conversation.id);
                Navigator.of(context).pop();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Conversation deleted')),
                  );
                }
              } catch (e) {
                Navigator.of(context).pop();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to delete conversation: $e')),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
  
  void _showExportDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Export Conversations'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Choose export format:'),
            SizedBox(height: 16),
            ListTile(
              leading: Icon(Icons.text_snippet),
              title: Text('Plain Text'),
              subtitle: Text('Simple text format'),
            ),
            ListTile(
              leading: Icon(Icons.table_chart),
              title: Text('CSV'),
              subtitle: Text('Spreadsheet compatible'),
            ),
            ListTile(
              leading: Icon(Icons.code),
              title: Text('JSON'),
              subtitle: Text('Machine readable format'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              // TODO: Implement export functionality
            },
            child: const Text('Export'),
          ),
        ],
      ),
    );
  }
  
  void _showAnalyticsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const AlertDialog(
        title: Text('Detailed Analytics'),
        content: Text('Advanced analytics dashboard would be implemented here with charts and detailed metrics.'),
      ),
    );
  }
}

// Helper Models
class ConversationHistory {
  final String id;
  final String title;
  final DateTime date;
  final Duration duration;
  final int participantCount;
  final int transcriptLength;
  final String summary;
  final List<String> tags;
  final SentimentType sentiment;
  final bool hasFactChecks;
  final bool hasActionItems;
  final bool isStarred;
  
  ConversationHistory({
    required this.id,
    required this.title,
    required this.date,
    required this.duration,
    required this.participantCount,
    required this.transcriptLength,
    required this.summary,
    required this.tags,
    required this.sentiment,
    required this.hasFactChecks,
    required this.hasActionItems,
    required this.isStarred,
  });
  
  ConversationHistory copyWith({
    String? id,
    String? title,
    DateTime? date,
    Duration? duration,
    int? participantCount,
    int? transcriptLength,
    String? summary,
    List<String>? tags,
    SentimentType? sentiment,
    bool? hasFactChecks,
    bool? hasActionItems,
    bool? isStarred,
  }) {
    return ConversationHistory(
      id: id ?? this.id,
      title: title ?? this.title,
      date: date ?? this.date,
      duration: duration ?? this.duration,
      participantCount: participantCount ?? this.participantCount,
      transcriptLength: transcriptLength ?? this.transcriptLength,
      summary: summary ?? this.summary,
      tags: tags ?? this.tags,
      sentiment: sentiment ?? this.sentiment,
      hasFactChecks: hasFactChecks ?? this.hasFactChecks,
      hasActionItems: hasActionItems ?? this.hasActionItems,
      isStarred: isStarred ?? this.isStarred,
    );
  }
}

enum SentimentType { positive, negative, neutral, mixed }
enum ConversationFilter { all, starred, withFactChecks, withActions, thisWeek }
enum ConversationSort { newest, oldest, longest, mostParticipants }

// Custom Widgets
class ConversationCard extends StatelessWidget {
  final ConversationModel conversation;
  final VoidCallback onTap;
  final VoidCallback onStar;
  final VoidCallback onShare;
  final VoidCallback onDelete;
  
  const ConversationCard({
    super.key,
    required this.conversation,
    required this.onTap,
    required this.onStar,
    required this.onShare,
    required this.onDelete,
  });
  
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      conversation.title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: onStar,
                    icon: Icon(
                      conversation.isPinned ? Icons.star : Icons.star_border,
                      color: conversation.isPinned ? Colors.amber : null,
                    ),
                  ),
                  PopupMenuButton<String>(
                    onSelected: (value) {
                      switch (value) {
                        case 'share':
                          onShare();
                          break;
                        case 'delete':
                          onDelete();
                          break;
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'share',
                        child: Row(
                          children: [
                            Icon(Icons.share),
                            SizedBox(width: 8),
                            Text('Share'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete, color: Colors.red),
                            SizedBox(width: 8),
                            Text('Delete', style: TextStyle(color: Colors.red)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                conversation.description ?? 
                (conversation.segments.isNotEmpty 
                  ? conversation.segments.take(2).map((s) => s.text).join(' ').length > 100
                    ? '${conversation.segments.take(2).map((s) => s.text).join(' ').substring(0, 100)}...'
                    : conversation.segments.take(2).map((s) => s.text).join(' ')
                  : 'No content available'),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 12),
              
              // Tags
              if (conversation.tags.isNotEmpty)
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: conversation.tags.take(3).map((tag) => Chip(
                    label: Text(tag),
                    backgroundColor: theme.colorScheme.surfaceVariant,
                    labelStyle: theme.textTheme.labelSmall,
                    visualDensity: VisualDensity.compact,
                  )).toList(),
                ),
              
              const SizedBox(height: 12),
              
              // Metadata
              Row(
                children: [
                  Icon(
                    Icons.schedule,
                    size: 16,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    DateFormat('MMM d, h:mm a').format(conversation.startTime),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Icon(
                    Icons.timer,
                    size: 16,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${conversation.duration.inMinutes}m',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Icon(
                    Icons.people,
                    size: 16,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${conversation.participants.length}',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const Spacer(),
                  
                  // Features
                  if (conversation.hasAIAnalysis)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'AI',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: Colors.green,
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
}