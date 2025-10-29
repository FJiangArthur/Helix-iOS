import 'package:flutter/material.dart';
import '../services/evenai.dart';

/// US 2.3: AI Assistant screen with live insights
class AIAssistantScreen extends StatefulWidget {
  const AIAssistantScreen({super.key});

  @override
  State<AIAssistantScreen> createState() => _AIAssistantScreenState();
}

class _AIAssistantScreenState extends State<AIAssistantScreen> {
  final _evenAI = EvenAI.get;
  Map<String, dynamic>? _currentInsights;

  @override
  void initState() {
    super.initState();
    // Listen to insights stream
    _evenAI.insightsStream.listen((insights) {
      if (mounted) {
        setState(() {
          _currentInsights = insights;
        });
      }
    });
    // Load current insights
    _loadInsights();
  }

  void _loadInsights() {
    setState(() {
      _currentInsights = _evenAI.getInsights();
    });
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader('AI Personas', Icons.psychology),
          _buildPersonaCards(context),
          const SizedBox(height: 24),
          
          _buildSectionHeader('Real-time Analysis', Icons.analytics),
          _buildAnalysisCard(context),
          const SizedBox(height: 24),
          
          _buildSectionHeader('Fact Checking', Icons.fact_check),
          _buildFactCheckCard(context),
          const SizedBox(height: 24),
          
          _buildSectionHeader('Conversation Insights', Icons.insights),
          _buildInsightsCard(context),
          const SizedBox(height: 24),
          
          _buildSectionHeader('LLM Providers', Icons.hub),
          _buildProvidersCard(context),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        children: [
          Icon(icon, size: 24),
          const SizedBox(width: 8),
          Text(
            title,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPersonaCards(BuildContext context) {
    final personas = [
      {
        'name': 'Professional',
        'icon': Icons.work,
        'description': 'Business context and formal analysis',
        'color': Colors.blue,
      },
      {
        'name': 'Creative',
        'icon': Icons.palette,
        'description': 'Innovative ideas and brainstorming',
        'color': Colors.purple,
      },
      {
        'name': 'Technical',
        'icon': Icons.code,
        'description': 'Technical details and debugging',
        'color': Colors.green,
      },
      {
        'name': 'Educational',
        'icon': Icons.school,
        'description': 'Learning and knowledge sharing',
        'color': Colors.orange,
      },
    ];

    return SizedBox(
      height: 120,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: personas.length,
        itemBuilder: (context, index) {
          final persona = personas[index];
          return Container(
            width: 140,
            margin: const EdgeInsets.only(right: 12),
            child: Card(
              elevation: 2,
              color: (persona['color'] as Color).withValues(alpha: 0.1),
              child: InkWell(
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('${persona['name']} persona selected'),
                      duration: const Duration(seconds: 1),
                    ),
                  );
                },
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        persona['icon'] as IconData,
                        size: 32,
                        color: persona['color'] as Color,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        persona['name'] as String,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        persona['description'] as String,
                        style: const TextStyle(fontSize: 10),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildAnalysisCard(BuildContext context) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.mic, color: Colors.green),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Context-Aware Processing',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'Analyzing conversation in real-time',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            LinearProgressIndicator(
              value: 0.7,
              backgroundColor: Colors.grey.withValues(alpha: 0.2),
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.green),
            ),
            const SizedBox(height: 8),
            const Text(
              'Processing: Speaker intent, emotional context, key topics',
              style: TextStyle(fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFactCheckCard(BuildContext context) {
    final facts = [
      {'statement': 'Flutter supports 6 platforms', 'status': 'verified', 'confidence': 0.95},
      {'statement': 'Meeting scheduled for tomorrow', 'status': 'unverified', 'confidence': 0.60},
      {'statement': 'Budget increased by 20%', 'status': 'checking', 'confidence': 0.75},
    ];

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: facts.map((fact) {
            IconData icon;
            Color color;
            
            switch (fact['status']) {
              case 'verified':
                icon = Icons.check_circle;
                color = Colors.green;
                break;
              case 'unverified':
                icon = Icons.help_outline;
                color = Colors.orange;
                break;
              default:
                icon = Icons.refresh;
                color = Colors.blue;
            }

            return Padding(
              padding: const EdgeInsets.only(bottom: 12.0),
              child: Row(
                children: [
                  Icon(icon, color: color, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          fact['statement'] as String,
                          style: const TextStyle(fontSize: 14),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Text(
                              'Confidence: ${((fact['confidence'] as double) * 100).toInt()}%',
                              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                            ),
                            const SizedBox(width: 8),
                            SizedBox(
                              width: 60,
                              height: 4,
                              child: LinearProgressIndicator(
                                value: fact['confidence'] as double,
                                backgroundColor: Colors.grey.withValues(alpha: 0.2),
                                valueColor: AlwaysStoppedAnimation<Color>(color),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildInsightsCard(BuildContext context) {
    // US 2.3: Use live insights data
    if (_currentInsights == null || _currentInsights!['summary'] == null || _currentInsights!['summary'].isEmpty) {
      return Card(
        elevation: 2,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              Icon(Icons.insights, size: 48, color: Colors.grey[400]),
              const SizedBox(height: 8),
              Text(
                'No insights yet',
                style: TextStyle(color: Colors.grey[600], fontSize: 16),
              ),
              const SizedBox(height: 4),
              Text(
                'Start a conversation to see AI-generated insights',
                style: TextStyle(color: Colors.grey[500], fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    final summary = _currentInsights!['summary'] as String? ?? 'No summary available';
    final keyPoints = (_currentInsights!['keyPoints'] as List?)?.cast<String>() ?? [];
    final actionItems = (_currentInsights!['actionItems'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final sentiment = _currentInsights!['sentiment'] as Map<String, dynamic>?;

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Summary
            _buildInsightItem(
              Icons.summarize,
              'Summary',
              summary,
              Colors.blue,
            ),

            // Key Points
            if (keyPoints.isNotEmpty) ...[
              const Divider(),
              _buildInsightItem(
                Icons.topic,
                'Key Points',
                keyPoints.join(' • '),
                Colors.green,
              ),
            ],

            // Action Items
            if (actionItems.isNotEmpty) ...[
              const Divider(),
              _buildActionItemsInsight(actionItems),
            ],

            // Sentiment
            if (sentiment != null) ...[
              const Divider(),
              _buildSentimentInsight(sentiment),
            ],

            // Refresh button
            const Divider(),
            Center(
              child: TextButton.icon(
                onPressed: () async {
                  await _evenAI.generateInsights();
                  _loadInsights();
                },
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('Refresh Insights'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionItemsInsight(List<Map<String, dynamic>> actionItems) {
    final itemsText = actionItems.map((item) {
      final task = item['task'] as String? ?? 'Unknown task';
      final priority = item['priority'] as String? ?? 'medium';
      final emoji = priority == 'high' ? '🔴' : priority == 'low' ? '🟢' : '🟡';
      return '$emoji $task';
    }).join('\n');

    return _buildInsightItem(
      Icons.task_alt,
      'Action Items (${actionItems.length})',
      itemsText,
      Colors.purple,
    );
  }

  Widget _buildSentimentInsight(Map<String, dynamic> sentiment) {
    final sentimentType = sentiment['sentiment'] as String? ?? 'neutral';
    final score = sentiment['score'] as double? ?? 0.0;

    IconData icon;
    Color color;
    String description;

    if (sentimentType == 'positive') {
      icon = Icons.sentiment_satisfied;
      color = Colors.green;
      description = 'Positive tone (${(score * 100).toInt()}% confidence)';
    } else if (sentimentType == 'negative') {
      icon = Icons.sentiment_dissatisfied;
      color = Colors.red;
      description = 'Negative tone (${(score.abs() * 100).toInt()}% confidence)';
    } else {
      icon = Icons.sentiment_neutral;
      color = Colors.orange;
      description = 'Neutral tone';
    }

    return _buildInsightItem(icon, 'Sentiment', description, color);
  }

  Widget _buildInsightItem(IconData icon, String title, String content, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  content,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[700],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProvidersCard(BuildContext context) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            _buildProviderTile(
              'OpenAI GPT-4',
              'Advanced reasoning and analysis',
              Icons.auto_awesome,
              Colors.teal,
              true,
            ),
            const Divider(),
            _buildProviderTile(
              'Anthropic',
              'Detailed conversation understanding',
              Icons.psychology_alt,
              Colors.indigo,
              false,
            ),
            const Divider(),
            _buildProviderTile(
              'Local LLM',
              'Privacy-focused on-device processing',
              Icons.smartphone,
              Colors.grey,
              false,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProviderTile(String name, String description, IconData icon, Color color, bool isActive) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: color),
      ),
      title: Text(name),
      subtitle: Text(
        description,
        style: const TextStyle(fontSize: 12),
      ),
      trailing: Switch(
        value: isActive,
        onChanged: (value) {},
        activeThumbColor: color,
      ),
    );
  }
}