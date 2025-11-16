import 'dart:async';
import 'ai/ai_coordinator.dart';
import 'package:flutter_helix/utils/app_logger.dart';

/// Conversation insights tracker for US 2.3
/// Accumulates conversation text and generates insights periodically
class ConversationInsights {
  static ConversationInsights? _instance;
  static ConversationInsights get instance => _instance ??= ConversationInsights._();

  ConversationInsights._();

  final _aiCoordinator = AICoordinator.instance;

  // Conversation state
  final List<String> _conversationBuffer = [];
  String _currentSummary = '';
  List<String> _keyPoints = [];
  List<Map<String, dynamic>> _actionItems = [];
  Map<String, dynamic>? _lastSentiment;
  DateTime? _lastUpdateTime;

  // Configuration
  static const int _minWordsForSummary = 50;  // Minimum words before generating summary
  static const int _summaryIntervalSeconds = 30;  // Generate summary every 30s

  Timer? _summaryTimer;

  // Getters for current insights
  String get summary => _currentSummary;
  List<String> get keyPoints => List.unmodifiable(_keyPoints);
  List<Map<String, dynamic>> get actionItems => List.unmodifiable(_actionItems);
  Map<String, dynamic>? get sentiment => _lastSentiment;
  DateTime? get lastUpdateTime => _lastUpdateTime;

  bool get hasInsights => _currentSummary.isNotEmpty;

  /// Stream of insights updates
  final _insightsController = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get insightsStream => _insightsController.stream;

  /// Add conversation text to the buffer
  void addConversationText(String text) {
    if (text.trim().isEmpty) return;

    _conversationBuffer.add(text);

    // Start automatic summary generation if not already running
    if (_summaryTimer == null || !_summaryTimer!.isActive) {
      _startSummaryTimer();
    }
  }

  /// Generate insights for the current conversation buffer
  Future<void> generateInsights() async {
    if (_conversationBuffer.isEmpty) return;

    final fullText = _conversationBuffer.join(' ');
    final wordCount = fullText.split(' ').length;

    // Need minimum words for meaningful summary
    if (wordCount < _minWordsForSummary) {
      return;
    }

    try {
      // Generate summary
      final summaryResult = await _aiCoordinator.summarize(fullText);
      if (!summaryResult.containsKey('error')) {
        _currentSummary = summaryResult['summary'] as String? ?? '';
        _keyPoints = (summaryResult['keyPoints'] as List?)?.cast<String>() ?? [];
      }

      // Extract action items
      final actionItemsResult = await _aiCoordinator.extractActionItems(fullText);
      if (actionItemsResult.isNotEmpty) {
        _actionItems = actionItemsResult;
      }

      // Analyze sentiment
      final sentimentResult = await _aiCoordinator.analyzeSentiment(fullText);
      if (!sentimentResult.containsKey('error')) {
        _lastSentiment = sentimentResult;
      }

      _lastUpdateTime = DateTime.now();

      // Emit insights update
      _insightsController.add({
        'summary': _currentSummary,
        'keyPoints': _keyPoints,
        'actionItems': _actionItems,
        'sentiment': _lastSentiment,
        'timestamp': _lastUpdateTime,
      });
    } catch (e) {
      appLogger.i("Error generating insights: $e");
    }
  }

  /// Start automatic summary generation timer
  void _startSummaryTimer() {
    _summaryTimer?.cancel();
    _summaryTimer = Timer.periodic(
      Duration(seconds: _summaryIntervalSeconds),
      (_) => generateInsights(),
    );
  }

  /// Clear all conversation data and insights
  void clear() {
    _conversationBuffer.clear();
    _currentSummary = '';
    _keyPoints.clear();
    _actionItems.clear();
    _lastSentiment = null;
    _lastUpdateTime = null;
    _summaryTimer?.cancel();
    _summaryTimer = null;
  }

  /// Get full conversation text
  String getFullConversation() {
    return _conversationBuffer.join('\n');
  }

  /// Get conversation statistics
  Map<String, dynamic> getStats() {
    final fullText = _conversationBuffer.join(' ');
    return {
      'messageCount': _conversationBuffer.length,
      'wordCount': fullText.split(' ').where((w) => w.isNotEmpty).length,
      'hasInsights': hasInsights,
      'lastUpdate': _lastUpdateTime?.toIso8601String() ?? 'never',
    };
  }

  /// Dispose resources
  void dispose() {
    _summaryTimer?.cancel();
    _insightsController.close();
    clear();
  }
}
