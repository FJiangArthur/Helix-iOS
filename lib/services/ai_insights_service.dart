// ABOUTME: AI insights service for generating real-time conversation intelligence
// ABOUTME: Provides contextual suggestions, analysis summaries, and smart conversation assistance

import 'dart:async';
import 'dart:collection';

import '../models/analysis_result.dart';
import '../models/transcription_segment.dart';
import '../models/conversation_model.dart';
import 'llm_service.dart';
import '../core/utils/logging_service.dart';

/// Service for generating AI-powered conversation insights
class AIInsightsService {
  static const String _tag = 'AIInsightsService';
  
  final LLMService _llmService;
  final LoggingService _logger;
  
  // Insights management
  final Map<String, ConversationInsight> _insights = {};
  final StreamController<ConversationInsight> _insightsController = StreamController.broadcast();
  
  // Conversation context
  final Queue<TranscriptionSegment> _conversationBuffer = Queue();
  final int _maxBufferSize = 50; // Keep last 50 segments
  
  // Timing and triggers
  Timer? _analysisTimer;
  Duration _analysisInterval = const Duration(seconds: 10);
  int _minWordsForInsight = 20;
  
  // Configuration
  bool _isEnabled = true;
  InsightType _enabledTypes = InsightType.all;
  double _confidenceThreshold = 0.6;
  
  AIInsightsService({
    required LLMService llmService,
    required LoggingService logger,
  })  : _llmService = llmService,
        _logger = logger;
  
  /// Stream of generated insights
  Stream<ConversationInsight> get insights => _insightsController.stream;
  
  /// Whether insights are enabled
  bool get isEnabled => _isEnabled;
  
  /// Current enabled insight types
  InsightType get enabledTypes => _enabledTypes;
  
  /// Initialize the service
  Future<void> initialize() async {
    _logger.log(_tag, 'Initializing AI insights service', LogLevel.info);
    
    if (!_llmService.isInitialized) {
      throw Exception('LLM service must be initialized first');
    }
    
    _startPeriodicAnalysis();
    _logger.log(_tag, 'AI insights service initialized', LogLevel.info);
  }
  
  /// Process new transcription segments
  Future<void> processTranscription(List<TranscriptionSegment> segments) async {
    if (!_isEnabled || segments.isEmpty) return;
    
    try {
      // Add to conversation buffer
      for (final segment in segments) {
        _conversationBuffer.add(segment);
        
        // Maintain buffer size
        if (_conversationBuffer.length > _maxBufferSize) {
          _conversationBuffer.removeFirst();
        }
      }
      
      // Check if we should generate immediate insights
      final recentText = segments.map((s) => s.text).join(' ');
      if (_shouldGenerateImmediateInsight(recentText)) {
        await _generateInsights(immediate: true);
      }
      
    } catch (e) {
      _logger.log(_tag, 'Error processing transcription: $e', LogLevel.error);
    }
  }
  
  /// Generate insights for current conversation context
  Future<void> generateInsights() async {
    if (!_isEnabled) return;
    
    try {
      await _generateInsights();
    } catch (e) {
      _logger.log(_tag, 'Error generating insights: $e', LogLevel.error);
    }
  }
  
  /// Get insight by ID
  ConversationInsight? getInsight(String insightId) {
    return _insights[insightId];
  }
  
  /// Get recent insights
  List<ConversationInsight> getRecentInsights({int limit = 10}) {
    final sorted = _insights.values.toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    
    return sorted.take(limit).toList();
  }
  
  /// Get insights by type
  List<ConversationInsight> getInsightsByType(InsightCategory category) {
    return _insights.values
        .where((insight) => insight.category == category)
        .toList();
  }
  
  /// Configure the service
  void configure({
    bool? enabled,
    InsightType? enabledTypes,
    double? confidenceThreshold,
    Duration? analysisInterval,
    int? minWordsForInsight,
  }) {
    if (enabled != null) {
      _isEnabled = enabled;
      if (enabled) {
        _startPeriodicAnalysis();
      } else {
        _stopPeriodicAnalysis();
      }
    }
    
    if (enabledTypes != null) _enabledTypes = enabledTypes;
    if (confidenceThreshold != null) _confidenceThreshold = confidenceThreshold;
    if (analysisInterval != null) {
      _analysisInterval = analysisInterval;
      _restartPeriodicAnalysis();
    }
    if (minWordsForInsight != null) _minWordsForInsight = minWordsForInsight;
    
    _logger.log(_tag, 'Service configured: enabled=$_isEnabled', LogLevel.info);
  }
  
  /// Clear all insights
  void clearInsights() {
    _insights.clear();
    _logger.log(_tag, 'Insights cleared', LogLevel.info);
  }
  
  /// Get service statistics
  Map<String, dynamic> getStatistics() {
    final categoryCount = <String, int>{};
    for (final insight in _insights.values) {
      final category = insight.category.name;
      categoryCount[category] = (categoryCount[category] ?? 0) + 1;
    }
    
    return {
      'isEnabled': _isEnabled,
      'totalInsights': _insights.length,
      'bufferSize': _conversationBuffer.length,
      'enabledTypes': _enabledTypes.name,
      'confidenceThreshold': _confidenceThreshold,
      'insightsByCategory': categoryCount,
      'analysisInterval': _analysisInterval.inSeconds,
    };
  }
  
  /// Dispose of the service
  Future<void> dispose() async {
    _stopPeriodicAnalysis();
    await _insightsController.close();
    _insights.clear();
    _conversationBuffer.clear();
    _logger.log(_tag, 'AI insights service disposed', LogLevel.info);
  }
  
  // Private methods
  
  void _startPeriodicAnalysis() {
    _analysisTimer?.cancel();
    _analysisTimer = Timer.periodic(_analysisInterval, (_) => _generateInsights());
  }
  
  void _stopPeriodicAnalysis() {
    _analysisTimer?.cancel();
    _analysisTimer = null;
  }
  
  void _restartPeriodicAnalysis() {
    _stopPeriodicAnalysis();
    if (_isEnabled) {
      _startPeriodicAnalysis();
    }
  }
  
  bool _shouldGenerateImmediateInsight(String text) {
    // Check for trigger phrases that warrant immediate insights
    final triggerPhrases = [
      'action item',
      'follow up',
      'deadline',
      'decision',
      'important',
      'urgent',
      'question',
      'clarification',
      'concern',
      'issue',
      'problem',
      'solution',
    ];
    
    final lowerText = text.toLowerCase();
    return triggerPhrases.any((phrase) => lowerText.contains(phrase));
  }
  
  Future<void> _generateInsights({bool immediate = false}) async {
    if (_conversationBuffer.isEmpty) return;
    
    try {
      final conversationText = _conversationBuffer
          .map((s) => s.text)
          .join(' ');
      
      if (conversationText.split(' ').length < _minWordsForInsight) {
        return;
      }
      
      _logger.log(_tag, 'Generating insights for conversation', LogLevel.debug);
      
      // Generate different types of insights based on configuration
      final insights = <ConversationInsight>[];
      
      if (_enabledTypes.hasFlag(InsightType.summary)) {
        final summaryInsight = await _generateSummaryInsight(conversationText);
        if (summaryInsight != null) insights.add(summaryInsight);
      }
      
      if (_enabledTypes.hasFlag(InsightType.actionItems)) {
        final actionInsights = await _generateActionItemInsights(conversationText);
        insights.addAll(actionInsights);
      }
      
      if (_enabledTypes.hasFlag(InsightType.questions)) {
        final questionInsights = await _generateQuestionInsights(conversationText);
        insights.addAll(questionInsights);
      }
      
      if (_enabledTypes.hasFlag(InsightType.sentiment)) {
        final sentimentInsight = await _generateSentimentInsight(conversationText);
        if (sentimentInsight != null) insights.add(sentimentInsight);
      }
      
      if (_enabledTypes.hasFlag(InsightType.topics)) {
        final topicInsights = await _generateTopicInsights(conversationText);
        insights.addAll(topicInsights);
      }
      
      if (_enabledTypes.hasFlag(InsightType.suggestions)) {
        final suggestionInsights = await _generateSuggestionInsights(conversationText);
        insights.addAll(suggestionInsights);
      }
      
      // Store and emit insights
      for (final insight in insights) {
        if (insight.confidence >= _confidenceThreshold) {
          _insights[insight.id] = insight;
          _insightsController.add(insight);
          
          _logger.log(_tag, 
            'Generated ${insight.category.name} insight: ${insight.title}',
            LogLevel.info);
        }
      }
      
    } catch (e) {
      _logger.log(_tag, 'Error generating insights: $e', LogLevel.error);
    }
  }
  
  Future<ConversationInsight?> _generateSummaryInsight(String text) async {
    try {
      final summary = await _llmService.generateSummary(
        ConversationModel(
          id: 'temp_${DateTime.now().millisecondsSinceEpoch}',
          title: 'Current Conversation',
          startTime: DateTime.now().subtract(const Duration(minutes: 10)),
          lastUpdated: DateTime.now(),
          participants: ['User'],
          segments: [],
        ),
      );
      
      return ConversationInsight(
        id: 'summary_${DateTime.now().millisecondsSinceEpoch}',
        category: InsightCategory.summary,
        title: 'Conversation Summary',
        content: summary.summary,
        confidence: summary.confidence,
        timestamp: DateTime.now(),
        metadata: {
          'keyPoints': summary.keyPoints,
          'topics': summary.topics,
          'tone': summary.tone,
        },
      );
    } catch (e) {
      _logger.log(_tag, 'Error generating summary insight: $e', LogLevel.error);
      return null;
    }
  }
  
  Future<List<ConversationInsight>> _generateActionItemInsights(String text) async {
    try {
      final actionItems = await _llmService.extractActionItems(text);
      
      return actionItems.map((action) {
        return ConversationInsight(
          id: 'action_${action.id}',
          category: InsightCategory.actionItem,
          title: 'Action Item: ${action.description}',
          content: action.description,
          confidence: action.confidence,
          timestamp: DateTime.now(),
          priority: _mapActionPriorityToInsightPriority(action.priority),
          metadata: {
            'assignee': action.assignee,
            'dueDate': action.dueDate?.toIso8601String(),
            'context': action.context,
          },
        );
      }).toList();
    } catch (e) {
      _logger.log(_tag, 'Error generating action item insights: $e', LogLevel.error);
      return [];
    }
  }
  
  Future<List<ConversationInsight>> _generateQuestionInsights(String text) async {
    try {
      // Use LLM to detect questions and unresolved topics
      await _llmService.askQuestion(
        'Identify unresolved questions and topics that need clarification in this conversation. '
        'Return as JSON array of objects with "question" and "context" fields.',
        text,
      );
      
      // Parse questions (simplified for now)
      final questions = <String>[];
      
      // Simple regex to find question marks
      final questionRegex = RegExp(r'[^.!?]*\?');
      final matches = questionRegex.allMatches(text);
      for (final match in matches) {
        questions.add(match.group(0)?.trim() ?? '');
      }
      
      return questions.map((question) {
        return ConversationInsight(
          id: 'question_${DateTime.now().millisecondsSinceEpoch}_${questions.indexOf(question)}',
          category: InsightCategory.question,
          title: 'Unresolved Question',
          content: question,
          confidence: 0.7,
          timestamp: DateTime.now(),
          priority: InsightPriority.medium,
        );
      }).toList();
    } catch (e) {
      _logger.log(_tag, 'Error generating question insights: $e', LogLevel.error);
      return [];
    }
  }
  
  Future<ConversationInsight?> _generateSentimentInsight(String text) async {
    try {
      final sentiment = await _llmService.analyzeSentiment(text);
      
      String content = 'Overall sentiment: ${sentiment.overallSentiment.name}';
      if (sentiment.dominantEmotion != null) {
        content += '\nDominant emotion: ${sentiment.dominantEmotion}';
      }
      if (sentiment.tone != null) {
        content += '\nTone: ${sentiment.tone}';
      }
      
      return ConversationInsight(
        id: 'sentiment_${DateTime.now().millisecondsSinceEpoch}',
        category: InsightCategory.sentiment,
        title: 'Conversation Sentiment',
        content: content,
        confidence: sentiment.confidence,
        timestamp: DateTime.now(),
        priority: sentiment.isNegative ? InsightPriority.high : InsightPriority.low,
        metadata: {
          'sentiment': sentiment.overallSentiment.name,
          'emotions': sentiment.emotions,
          'keyPhrases': sentiment.keyPhrases,
        },
      );
    } catch (e) {
      _logger.log(_tag, 'Error generating sentiment insight: $e', LogLevel.error);
      return null;
    }
  }
  
  Future<List<ConversationInsight>> _generateTopicInsights(String text) async {
    try {
      // For now, use a simple approach to identify topics
      // In a real implementation, this would use more sophisticated NLP
      
      final topics = <String>[];
      
      // Basic keyword extraction (this would be much more sophisticated in production)
      final words = text.toLowerCase().split(' ');
      final topicKeywords = <String, int>{};
      
      for (final word in words) {
        if (word.length > 4 && !_isStopWord(word)) {
          topicKeywords[word] = (topicKeywords[word] ?? 0) + 1;
        }
      }
      
      // Get most frequent words as topics
      final sortedTopics = topicKeywords.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      
      topics.addAll(sortedTopics.take(3).map((e) => e.key));
      
      return topics.map((topic) {
        return ConversationInsight(
          id: 'topic_${DateTime.now().millisecondsSinceEpoch}_${topics.indexOf(topic)}',
          category: InsightCategory.topic,
          title: 'Key Topic: ${topic.toUpperCase()}',
          content: 'This topic appears frequently in the conversation',
          confidence: 0.6,
          timestamp: DateTime.now(),
          metadata: {
            'keyword': topic,
            'frequency': topicKeywords[topic],
          },
        );
      }).toList();
    } catch (e) {
      _logger.log(_tag, 'Error generating topic insights: $e', LogLevel.error);
      return [];
    }
  }
  
  Future<List<ConversationInsight>> _generateSuggestionInsights(String text) async {
    try {
      // Generate contextual suggestions based on conversation content
      final suggestions = <String>[];
      
      if (text.toLowerCase().contains('meeting') || text.toLowerCase().contains('schedule')) {
        suggestions.add('Consider scheduling a follow-up meeting to continue this discussion');
      }
      
      if (text.toLowerCase().contains('deadline') || text.toLowerCase().contains('due')) {
        suggestions.add('Add these deadlines to your calendar for tracking');
      }
      
      if (text.toLowerCase().contains('decision') || text.toLowerCase().contains('decide')) {
        suggestions.add('Document this decision for future reference');
      }
      
      if (text.toLowerCase().contains('question') || text.toLowerCase().contains('unclear')) {
        suggestions.add('Consider clarifying these points before proceeding');
      }
      
      return suggestions.map((suggestion) {
        return ConversationInsight(
          id: 'suggestion_${DateTime.now().millisecondsSinceEpoch}_${suggestions.indexOf(suggestion)}',
          category: InsightCategory.suggestion,
          title: 'Suggestion',
          content: suggestion,
          confidence: 0.7,
          timestamp: DateTime.now(),
          priority: InsightPriority.medium,
        );
      }).toList();
    } catch (e) {
      _logger.log(_tag, 'Error generating suggestion insights: $e', LogLevel.error);
      return [];
    }
  }
  
  bool _isStopWord(String word) {
    const stopWords = {
      'the', 'a', 'an', 'and', 'or', 'but', 'in', 'on', 'at', 'to', 'for',
      'of', 'with', 'by', 'from', 'about', 'into', 'through', 'during',
      'before', 'after', 'above', 'below', 'up', 'down', 'out', 'off', 'over',
      'under', 'again', 'further', 'then', 'once', 'here', 'there', 'when',
      'where', 'why', 'how', 'all', 'any', 'both', 'each', 'few', 'more',
      'most', 'other', 'some', 'such', 'no', 'nor', 'not', 'only', 'own',
      'same', 'so', 'than', 'too', 'very', 'can', 'will', 'just', 'should',
      'now', 'was', 'were', 'been', 'have', 'has', 'had', 'do', 'does', 'did',
      'would', 'could', 'might', 'must', 'shall', 'may', 'am', 'is', 'are'
    };
    
    return stopWords.contains(word);
  }
  
  InsightPriority _mapActionPriorityToInsightPriority(ActionItemPriority priority) {
    switch (priority) {
      case ActionItemPriority.urgent:
        return InsightPriority.urgent;
      case ActionItemPriority.high:
        return InsightPriority.high;
      case ActionItemPriority.medium:
        return InsightPriority.medium;
      case ActionItemPriority.low:
        return InsightPriority.low;
    }
  }
}

/// Conversation insight model
class ConversationInsight {
  final String id;
  final InsightCategory category;
  final String title;
  final String content;
  final double confidence;
  final DateTime timestamp;
  final InsightPriority priority;
  final Map<String, dynamic> metadata;
  
  ConversationInsight({
    required this.id,
    required this.category,
    required this.title,
    required this.content,
    required this.confidence,
    required this.timestamp,
    this.priority = InsightPriority.medium,
    this.metadata = const {},
  });
  
  /// Whether this is a high-confidence insight
  bool get isHighConfidence => confidence > 0.8;
  
  /// Whether this insight is recent (within last 5 minutes)
  bool get isRecent => DateTime.now().difference(timestamp).inMinutes < 5;
  
  /// Age of the insight
  Duration get age => DateTime.now().difference(timestamp);
}

/// Categories of insights
enum InsightCategory {
  summary,
  actionItem,
  question,
  sentiment,
  topic,
  suggestion,
  warning,
  opportunity,
}

/// Priority levels for insights
enum InsightPriority {
  low,
  medium,
  high,
  urgent,
}

/// Types of insights that can be enabled/disabled
enum InsightType {
  none,
  summary,
  actionItems,
  questions,
  sentiment,
  topics,
  suggestions,
  all;
  
  int get value {
    switch (this) {
      case InsightType.none:
        return 0;
      case InsightType.summary:
        return 1;
      case InsightType.actionItems:
        return 2;
      case InsightType.questions:
        return 4;
      case InsightType.sentiment:
        return 8;
      case InsightType.topics:
        return 16;
      case InsightType.suggestions:
        return 32;
      case InsightType.all:
        return 63; // Sum of all flags
    }
  }
  
  bool hasFlag(InsightType type) => (value & type.value) != 0;
}