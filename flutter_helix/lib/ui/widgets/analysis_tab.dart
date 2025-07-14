// ABOUTME: Enhanced analysis tab with fact-checking cards and AI insights
// ABOUTME: Displays real-time AI analysis, fact-checking, summaries, and action items

import 'package:flutter/material.dart';

class AnalysisTab extends StatefulWidget {
  const AnalysisTab({super.key});

  @override
  State<AnalysisTab> createState() => _AnalysisTabState();
}

class _AnalysisTabState extends State<AnalysisTab> with TickerProviderStateMixin {
  late TabController _tabController;
  bool _isAnalyzing = false;
  
  // Sample data for demonstration
  final List<FactCheckResult> _factChecks = [
    FactCheckResult(
      claim: 'The iPhone was first released in 2007',
      status: FactCheckStatus.verified,
      confidence: 0.98,
      sources: ['Apple Inc.', 'TechCrunch', 'Wikipedia'],
      explanation: 'Apple officially announced the iPhone on January 9, 2007, at the Macworld Conference & Expo.',
    ),
    FactCheckResult(
      claim: 'Climate change is causing sea levels to rise globally',
      status: FactCheckStatus.verified,
      confidence: 0.95,
      sources: ['NASA', 'NOAA', 'IPCC Report 2023'],
      explanation: 'Multiple scientific studies confirm global sea level rise due to thermal expansion and ice sheet melting.',
    ),
    FactCheckResult(
      claim: 'Electric cars produce zero emissions',
      status: FactCheckStatus.disputed,
      confidence: 0.82,
      sources: ['EPA', 'Union of Concerned Scientists'],
      explanation: 'While electric cars produce no direct emissions, electricity generation and battery production do create emissions.',
    ),
  ];

  final ConversationSummary _summary = ConversationSummary(
    summary: 'Discussion covered technology innovation, environmental impact, and the future of transportation. Key focus on electric vehicles and their environmental benefits versus traditional vehicles.',
    keyPoints: [
      'Electric vehicle adoption is accelerating globally',
      'Battery technology improvements are driving longer ranges',
      'Charging infrastructure needs continued expansion',
      'Environmental benefits depend on electricity source'
    ],
    decisions: [
      'Research electric vehicle options for company fleet',
      'Schedule meeting with sustainability team'
    ],
    questions: [
      'What is the total cost of ownership for EVs?',
      'How long until charging network is fully developed?'
    ],
    topics: ['Technology', 'Environment', 'Transportation', 'Sustainability'],
    confidence: 0.89,
  );

  final List<ActionItemResult> _actionItems = [
    ActionItemResult(
      id: '1',
      description: 'Research electric vehicle models for company fleet replacement',
      assignee: 'Fleet Manager',
      dueDate: DateTime.now().add(const Duration(days: 7)),
      priority: ActionItemPriority.high,
      confidence: 0.91,
      status: ActionItemStatus.pending,
    ),
    ActionItemResult(
      id: '2', 
      description: 'Schedule sustainability team meeting to discuss carbon footprint',
      priority: ActionItemPriority.medium,
      confidence: 0.85,
      status: ActionItemStatus.pending,
    ),
    ActionItemResult(
      id: '3',
      description: 'Calculate total cost of ownership comparison between gas and electric vehicles',
      dueDate: DateTime.now().add(const Duration(days: 14)),
      priority: ActionItemPriority.low,
      confidence: 0.78,
      status: ActionItemStatus.pending,
    ),
  ];

  final SentimentAnalysisResult _sentiment = SentimentAnalysisResult(
    overallSentiment: SentimentType.positive,
    confidence: 0.87,
    emotions: {
      'optimism': 0.7,
      'curiosity': 0.8,
      'concern': 0.3,
      'excitement': 0.6,
    },
  );

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Analysis'),
        backgroundColor: theme.colorScheme.surface,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(_isAnalyzing ? Icons.stop : Icons.refresh),
            onPressed: () {
              setState(() {
                _isAnalyzing = !_isAnalyzing;
              });
            },
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              // Handle menu actions
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'export',
                child: Row(
                  children: [
                    Icon(Icons.download),
                    SizedBox(width: 8),
                    Text('Export Analysis'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'settings',
                child: Row(
                  children: [
                    Icon(Icons.settings),
                    SizedBox(width: 8),
                    Text('Analysis Settings'),
                  ],
                ),
              ),
            ],
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.fact_check), text: 'Facts'),
            Tab(icon: Icon(Icons.summarize), text: 'Summary'),
            Tab(icon: Icon(Icons.assignment), text: 'Actions'),
            Tab(icon: Icon(Icons.sentiment_satisfied), text: 'Sentiment'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildFactCheckTab(theme),
          _buildSummaryTab(theme),
          _buildActionItemsTab(theme),
          _buildSentimentTab(theme),
        ],
      ),
    );
  }

  Widget _buildFactCheckTab(ThemeData theme) {
    if (_factChecks.isEmpty) {
      return _buildEmptyState(
        theme,
        Icons.fact_check_outlined,
        'No Facts to Check',
        'Start a conversation to see AI-powered fact-checking results',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _factChecks.length,
      itemBuilder: (context, index) {
        final factCheck = _factChecks[index];
        return FactCheckCard(factCheck: factCheck);
      },
    );
  }

  Widget _buildSummaryTab(ThemeData theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SummaryCard(summary: _summary),
          const SizedBox(height: 16),
          _buildInsightsList(theme),
        ],
      ),
    );
  }

  Widget _buildActionItemsTab(ThemeData theme) {
    if (_actionItems.isEmpty) {
      return _buildEmptyState(
        theme,
        Icons.assignment_outlined,
        'No Action Items',
        'AI will extract action items from your conversations',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _actionItems.length,
      itemBuilder: (context, index) {
        final actionItem = _actionItems[index];
        return ActionItemCard(actionItem: actionItem);
      },
    );
  }

  Widget _buildSentimentTab(ThemeData theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          SentimentCard(sentiment: _sentiment),
          const SizedBox(height: 16),
          _buildEmotionBreakdown(theme),
        ],
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme, IconData icon, String title, String subtitle) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 64,
            color: theme.colorScheme.outline,
          ),
          const SizedBox(height: 24),
          Text(
            title,
            style: theme.textTheme.headlineSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildInsightsList(ThemeData theme) {
    final insights = [
      'Conversation showed high engagement with technical topics',
      'Environmental consciousness is a key decision factor',
      'Cost analysis is needed before making final decisions',
      'Timeline expectations are realistic and achievable',
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.lightbulb_outlined, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'AI Insights',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...insights.map((insight) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    margin: const EdgeInsets.only(top: 6, right: 8),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      insight,
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
            )),
          ],
        ),
      ),
    );
  }

  Widget _buildEmotionBreakdown(ThemeData theme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Emotion Breakdown',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            ..._sentiment.emotions.entries.map((entry) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          entry.key.toUpperCase(),
                          style: theme.textTheme.labelMedium,
                        ),
                        Text(
                          '${(entry.value * 100).round()}%',
                          style: theme.textTheme.labelMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    LinearProgressIndicator(
                      value: entry.value,
                      backgroundColor: theme.colorScheme.outline.withOpacity(0.2),
                      valueColor: AlwaysStoppedAnimation<Color>(
                        _getEmotionColor(entry.key),
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

  Color _getEmotionColor(String emotion) {
    switch (emotion.toLowerCase()) {
      case 'optimism':
      case 'excitement':
        return Colors.green;
      case 'curiosity':
        return Colors.blue;
      case 'concern':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }
}

// Helper Models
class FactCheckResult {
  final String claim;
  final FactCheckStatus status;
  final double confidence;
  final List<String> sources;
  final String explanation;

  FactCheckResult({
    required this.claim,
    required this.status,
    required this.confidence,
    required this.sources,
    required this.explanation,
  });
}

enum FactCheckStatus { verified, disputed, uncertain }

class ConversationSummary {
  final String summary;
  final List<String> keyPoints;
  final List<String> decisions;
  final List<String> questions;
  final List<String> topics;
  final double confidence;

  ConversationSummary({
    required this.summary,
    required this.keyPoints,
    required this.decisions,
    required this.questions,
    required this.topics,
    required this.confidence,
  });
}

class ActionItemResult {
  final String id;
  final String description;
  final String? assignee;
  final DateTime? dueDate;
  final ActionItemPriority priority;
  final double confidence;
  final ActionItemStatus status;

  ActionItemResult({
    required this.id,
    required this.description,
    this.assignee,
    this.dueDate,
    required this.priority,
    required this.confidence,
    required this.status,
  });
}

enum ActionItemPriority { low, medium, high, urgent }
enum ActionItemStatus { pending, inProgress, completed, cancelled }

class SentimentAnalysisResult {
  final SentimentType overallSentiment;
  final double confidence;
  final Map<String, double> emotions;

  SentimentAnalysisResult({
    required this.overallSentiment,
    required this.confidence,
    required this.emotions,
  });
}

enum SentimentType { positive, negative, neutral, mixed }

// Custom Card Widgets
class FactCheckCard extends StatelessWidget {
  final FactCheckResult factCheck;

  const FactCheckCard({super.key, required this.factCheck});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    Color statusColor;
    IconData statusIcon;
    switch (factCheck.status) {
      case FactCheckStatus.verified:
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        break;
      case FactCheckStatus.disputed:
        statusColor = Colors.red;
        statusIcon = Icons.cancel;
        break;
      case FactCheckStatus.uncertain:
        statusColor = Colors.orange;
        statusIcon = Icons.help_outline;
        break;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(statusIcon, color: statusColor, size: 20),
                const SizedBox(width: 8),
                Text(
                  factCheck.status.name.toUpperCase(),
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: statusColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${(factCheck.confidence * 100).round()}%',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: statusColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              factCheck.claim,
              style: theme.textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              factCheck.explanation,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            if (factCheck.sources.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                children: factCheck.sources.map((source) => Chip(
                  label: Text(source),
                  backgroundColor: theme.colorScheme.surfaceVariant,
                  labelStyle: theme.textTheme.labelSmall,
                )).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class SummaryCard extends StatelessWidget {
  final ConversationSummary summary;

  const SummaryCard({super.key, required this.summary});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.summarize, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'Conversation Summary',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${(summary.confidence * 100).round()}%',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onPrimaryContainer,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              summary.summary,
              style: theme.textTheme.bodyMedium,
            ),
            if (summary.keyPoints.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(
                'Key Points',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              ...summary.keyPoints.map((point) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 4,
                      height: 4,
                      margin: const EdgeInsets.only(top: 8, right: 8),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    Expanded(child: Text(point, style: theme.textTheme.bodyMedium)),
                  ],
                ),
              )),
            ],
            if (summary.topics.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                children: summary.topics.map((topic) => Chip(
                  label: Text(topic),
                  backgroundColor: theme.colorScheme.secondaryContainer,
                  labelStyle: theme.textTheme.labelSmall,
                )).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class ActionItemCard extends StatelessWidget {
  final ActionItemResult actionItem;

  const ActionItemCard({super.key, required this.actionItem});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    Color priorityColor;
    switch (actionItem.priority) {
      case ActionItemPriority.urgent:
        priorityColor = Colors.red;
        break;
      case ActionItemPriority.high:
        priorityColor = Colors.orange;
        break;
      case ActionItemPriority.medium:
        priorityColor = Colors.blue;
        break;
      case ActionItemPriority.low:
        priorityColor = Colors.green;
        break;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: priorityColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  actionItem.priority.name.toUpperCase(),
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: priorityColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                if (actionItem.dueDate != null)
                  Text(
                    _formatDueDate(actionItem.dueDate!),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              actionItem.description,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
            if (actionItem.assignee != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    Icons.person_outline,
                    size: 16,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    actionItem.assignee!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatDueDate(DateTime dueDate) {
    final now = DateTime.now();
    final difference = dueDate.difference(now).inDays;
    
    if (difference == 0) {
      return 'Due today';
    } else if (difference == 1) {
      return 'Due tomorrow';
    } else if (difference > 0) {
      return 'Due in $difference days';
    } else {
      return 'Overdue by ${difference.abs()} days';
    }
  }
}

class SentimentCard extends StatelessWidget {
  final SentimentAnalysisResult sentiment;

  const SentimentCard({super.key, required this.sentiment});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    Color sentimentColor;
    IconData sentimentIcon;
    String sentimentText;
    
    switch (sentiment.overallSentiment) {
      case SentimentType.positive:
        sentimentColor = Colors.green;
        sentimentIcon = Icons.sentiment_very_satisfied;
        sentimentText = 'Positive';
        break;
      case SentimentType.negative:
        sentimentColor = Colors.red;
        sentimentIcon = Icons.sentiment_very_dissatisfied;
        sentimentText = 'Negative';
        break;
      case SentimentType.neutral:
        sentimentColor = Colors.grey;
        sentimentIcon = Icons.sentiment_neutral;
        sentimentText = 'Neutral';
        break;
      case SentimentType.mixed:
        sentimentColor = Colors.orange;
        sentimentIcon = Icons.sentiment_satisfied;
        sentimentText = 'Mixed';
        break;
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Icon(sentimentIcon, color: sentimentColor, size: 32),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Overall Sentiment',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      sentimentText,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: sentimentColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: sentimentColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    '${(sentiment.confidence * 100).round()}%',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: sentimentColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}