import 'package:flutter/material.dart';

class AIAssistantScreen extends StatelessWidget {
  const AIAssistantScreen({super.key});

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
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInsightItem(
              Icons.summarize,
              'Summary',
              'Discussion about Q4 product launch timeline and resource allocation',
              Colors.blue,
            ),
            const Divider(),
            _buildInsightItem(
              Icons.task_alt,
              'Action Items',
              '3 tasks identified: Review budget, Schedule follow-up, Prepare deck',
              Colors.purple,
            ),
            const Divider(),
            _buildInsightItem(
              Icons.sentiment_satisfied,
              'Sentiment',
              'Overall positive tone with some concerns about timeline',
              Colors.orange,
            ),
            const Divider(),
            _buildInsightItem(
              Icons.topic,
              'Key Topics',
              'Product launch, Budget, Timeline, Team resources',
              Colors.green,
            ),
          ],
        ),
      ),
    );
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
              'Anthropic Claude',
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